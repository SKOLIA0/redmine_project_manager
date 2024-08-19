require File.expand_path('../../test_helper', __FILE__)

class ProjectManagerTest < ActiveSupport::TestCase
  fixtures :projects, :roles, :users, :members, :member_roles

  setup do
    # Создаем роли Project Manager, Member и ConsultingDirector
    @project_manager_role = Role.create!(name: 'ProjectManager')
    @project_member_role = Role.create!(name: 'Member')
    @consulting_director_role = Role.create!(name: 'ConsultingDirector')

    # Создаем проект
    @project = Project.create!(name: 'Test Project', identifier: 'testproject')

    # Создаем двух пользователей: старого и нового менеджера проекта
    @old_manager = User.create!(login: 'old_manager', firstname: 'Old', lastname: 'Manager', mail: 'old_manager@example.com')
    @new_manager = User.create!(login: 'new_manager', firstname: 'New', lastname: 'Manager', mail: 'new_manager@example.com')

    # Добавляем старого менеджера как участника проекта с ролью Project Manager
    Member.create!(user: @old_manager, project: @project, roles: [@project_manager_role])

    # Создаем пользователя с ролью ConsultingDirector
    @consulting_director = User.create!(login: 'director', firstname: 'Director', lastname: 'User', mail: 'director@example.com')
    Member.create!(user: @consulting_director, project: @project, roles: [@consulting_director_role])

    # Создаем группу менеджеров проекта и добавляем туда пользователя
    @manager_group = Group.create!(lastname: 'GROUP_PROJECT_MANAGERS')
    @manager_group.users << @new_manager
  end

  # Тест: успешное назначение нового менеджера проекта, если у пользователя есть разрешение assign_project_manager
  test 'should allow assigning project manager if user has assign_project_manager permission' do
    # Устанавливаем текущего пользователя как ConsultingDirector
    User.current = @consulting_director

    # Назначаем права на редактирование проекта
    role = Role.find_by(name: 'ConsultingDirector')
    role.add_permission!(:assign_project_manager)

    # Назначаем старого менеджера проекту
    @project.update!(project_manager: @old_manager)

    # Проверяем, что старый менеджер назначен
    assert_equal @old_manager, @project.project_manager

    # Меняем менеджера проекта
    @project.update!(project_manager: @new_manager)

    # Проверяем, что новый менеджер назначен
    assert_equal @new_manager, @project.project_manager

    puts "\e[32mTest passed: User with assign_project_manager permission can assign project manager\e[0m"
  rescue => e
    puts "\e[31mTest failed: #{e.message}\e[0m"
    raise e
  end

  # Тест: запрет на назначение менеджера проекта, если у пользователя нет разрешения assign_project_manager
  test 'should not allow assigning project manager if user does not have assign_project_manager permission' do
    # Создаем пользователя без прав ConsultingDirector
    non_director_user = User.create!(login: 'non_director', firstname: 'Non', lastname: 'Director', mail: 'non_director@example.com')
    Member.create!(user: non_director_user, project: @project, roles: [@project_member_role])

    # Устанавливаем текущего пользователя как non_director_user
    User.current = non_director_user

    # Пытаемся назначить нового менеджера проекта
    assert_raises(ActiveRecord::RecordInvalid) do
      @project.update!(project_manager: @new_manager)
    end

    puts "\e[32mTest passed: User without assign_project_manager permission cannot assign project manager\e[0m"
  rescue => e
    puts "\e[31mTest failed: #{e.message}\e[0m"
    raise e
  end
end
