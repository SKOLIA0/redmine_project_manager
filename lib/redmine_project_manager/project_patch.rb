module RedmineProjectManager
  module ProjectPatch
    def self.included(base)
      base.class_eval do

        belongs_to :project_manager, class_name: 'User', optional: true

        # Разрешаем сохранение атрибута project_manager_id
        safe_attributes 'project_manager_id'

        # Валидация наличия менеджера проекта
        validate :project_manager_presence

        # Проверка прав на назначение менеджера проекта
        validate :check_assign_project_manager_permission, on: :update

        # Перед сохранением сохраняем старого менеджера
        before_save :store_old_manager

        # Вызываем метод после сохранения проекта
        after_save :assign_project_manager_role

        private

        # Проверка, что текущий пользователь имеет права на назначение менеджера проекта
        def check_assign_project_manager_permission
          unless User.current.allowed_to?(:assign_project_manager, self)
            # Добавляем ошибку и прерываем сохранение, если нет прав
            errors.add(:base, l(:error_no_permission_to_assign_project_manager))
            throw(:abort) # Останавливаем сохранение проекта
          end
        end

        # Сохраняем старого менеджера проекта до обновления
        def store_old_manager
          @old_project_manager = project_manager_id_was.present? ? User.find_by(id: project_manager_id_was) : nil
        end

        # Проверка, что менеджер проекта назначен, если существует группа GROUP_PROJECT_MANAGERS
        def project_manager_presence
          group = Group.find_by(lastname: 'GROUP_PROJECT_MANAGERS')

          if group.nil?
            Rails.logger.info "Group 'GROUP_PROJECT_MANAGERS' does not exist. Skipping project manager validation."
            return
          end

          if project_manager.nil?
            errors.add(:base, l(:blank))
          end
        end

        # Метод для изменения роли старого менеджера и назначения нового менеджера проекта
        def assign_project_manager_role
          # Проверяем наличие группы GROUP_PROJECT_MANAGERS
          group = Group.find_by(lastname: 'GROUP_PROJECT_MANAGERS')
          unless group
            Rails.logger.info "Group 'GROUP_PROJECT_MANAGERS' does not exist. Skipping role assignment."
            return
          end

          # Ищем роль "Project Manager"
          project_manager_role = Role.find_by(name: 'ProjectManager')
          project_member_role = Role.find_by(name: 'Member')

          # Если был старый менеджер, заменяем его роль на участника
          if @old_project_manager.present?
            old_member = Member.find_by(user_id: @old_project_manager.id, project_id: id)

            if old_member
              # Заменяем роль старого менеджера на роль "Участник проекта"
              old_member.role_ids = [project_member_role.id]
              old_member.save
            end
          end

          # Проверяем наличие нового менеджера проекта
          if project_manager.present?
            # Проверяем наличие членства для нового менеджера
            new_member = Member.find_by(user_id: project_manager.id, project_id: id)

            if new_member
              # Если участник уже есть, просто добавляем роль "Project Manager"
              new_member.role_ids = (new_member.role_ids + [project_manager_role.id]).uniq
              new_member.save
            else
              # Создаем новое членство с ролью Project Manager
              new_member = Member.new(
                user_id: project_manager.id,
                project_id: id,
                role_ids: [project_manager_role.id]
              )

              if new_member.save
                Rails.logger.info "Successfully assigned Project Manager role to #{project_manager.name}"
              else
                Rails.logger.error "Error assigning Project Manager role: #{new_member.errors.full_messages.join(', ')}"
              end
            end
          else
            Rails.logger.error "ProjectManager is nil. Cannot assign roles."
          end
        end
      end
    end
  end
end
