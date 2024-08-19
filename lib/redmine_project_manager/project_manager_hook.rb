module RedmineProjectManager
  class ProjectManagerHook < Redmine::Hook::ViewListener
    def view_projects_form(context = {})
      project = context[:project]
      f = context[:form]

      # Проверяем разрешение пользователя на назначение менеджера проекта
      if User.current.allowed_to?(:assign_project_manager, project)
        group = Group.find_by(lastname: 'GROUP_PROJECT_MANAGERS')

        if group && group.users.any?
          users = group.users.active
          # Рендерим частичное представление с полем выбора менеджера проекта
          context[:controller].send(:render_to_string, {
            :partial => 'hooks/project_manager_field',
            :locals => {:users => users, :f => f}
          })
        else
          # Логирование в случае отсутствия группы
          Rails.logger.info "Group 'GROUP_PROJECT_MANAGERS' does not exist or has no active users"
          ''
        end
      else
        # Если у пользователя нет разрешения, не показываем поле
        Rails.logger.info "User #{User.current.login} does not have permission to assign project manager"
        ''
      end
    end
  end
end
