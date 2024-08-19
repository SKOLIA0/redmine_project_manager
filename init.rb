require 'redmine'

# Инициализируем плагин
Redmine::Plugin.register :redmine_project_manager do
  name 'Redmine Project Manager plugin'
  author 'Nikolaj Slepchenko'
  description 'This plugin allows assigning project managers from a specific user group.'
  version '1.0.0'
  # Добавляем разрешение для назначения менеджера проекта
    permission :assign_project_manager, { projects: [:edit] }, require: :member
end

# Загружаем патчи и хуки
begin
  require_dependency File.expand_path('../lib/redmine_project_manager/project_patch', __FILE__)
rescue LoadError => e
  Rails.logger.error ">> Error loading project patch: #{e.message}"
end

begin
  require_dependency File.expand_path('../lib/redmine_project_manager/project_manager_hook', __FILE__)
 rescue LoadError => e
  Rails.logger.error ">> Error loading project manager hook: #{e.message}"
end

# Включаем патч в модель Project
begin
  unless Project.included_modules.include?(RedmineProjectManager::ProjectPatch)
    Project.send(:include, RedmineProjectManager::ProjectPatch)
  else
    Rails.logger.info ">> ProjectPatch already included in Project model"
  end
rescue StandardError => e
  Rails.logger.error ">> Error including ProjectPatch: #{e.message}"
end
