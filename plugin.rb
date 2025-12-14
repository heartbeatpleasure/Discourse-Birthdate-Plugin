# frozen_string_literal: true

# name: Discourse-Birthdate-Plugin
# about: Collect full birthdate (day/month/year) during signup with server-side validation and UX hooks
# version: 0.2.2
# authors: Chris
# url: https://github.com/heartbeatpleasure/Discourse-Birthdate-Plugin

enabled_site_setting :hbp_birthdate_enabled

after_initialize do
  require_relative "lib/hbp_birthdate/user_fields"
  require_relative "lib/hbp_birthdate/birthdate"
  require_relative "lib/hbp_birthdate/user_validator"

  # Ensure fields exist (safe; logs on failure)
  begin
    HbpBirthdate::UserFields.ensure! if SiteSetting.hbp_birthdate_enabled
  rescue => e
    Rails.logger.error(
      "hbp_birthdate: ensure! failed: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    )
  end

  # Expose IDs to the client/theme component (optional but useful)
  add_to_serializer(:site, :hbp_birthdate_user_field_ids) do
    begin
      HbpBirthdate::UserFields.ids
    rescue => e
      Rails.logger.error("hbp_birthdate: site serializer failed: #{e.class}: #{e.message}")
      {}
    end
  end

  # Later: age/birthday icon hooks can use these (already safe-wrapped)
  add_to_serializer(:user, :hbp_birthdate_age) do
    HbpBirthdate::Birthdate.age_for(object)
  rescue
    nil
  end

  add_to_serializer(:user, :hbp_birthdate_birthday_today) do
    HbpBirthdate::Birthdate.birthday_today?(object)
  rescue
    false
  end

  add_to_serializer(:user_card, :hbp_birthdate_age) do
    HbpBirthdate::Birthdate.age_for(object)
  rescue
    nil
  end

  add_to_serializer(:user_card, :hbp_birthdate_birthday_today) do
    HbpBirthdate::Birthdate.birthday_today?(object)
  rescue
    false
  end
end
