class AddTargetToSetting < ActiveRecord::Migration[7.1]
  def change
    add_reference :settings, :target, null: false, polymorphic: true, null: true

    Setting.all.each do |setting|
      setting.update(target_id: setting.user_id, target_type: 'User') if setting.user_id.present?
    end
  end
end
