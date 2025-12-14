# frozen_string_literal: true

module HbpBirthdate
  module UserValidator
    def self.included(base)
      base.validate :hbp_birthdate_validate_date
    end

    def hbp_birthdate_validate_date
      return unless SiteSetting.hbp_birthdate_enabled

      ids = HbpBirthdate::UserFields.ids
      return if ids.blank?

      day_key = "user_field_#{ids["day"]}"
      month_key = "user_field_#{ids["month"]}"
      year_key = "user_field_#{ids["year"]}"

      cf = respond_to?(:custom_fields) && custom_fields.is_a?(Hash) ? custom_fields : {}

      day = cf[day_key].to_s.strip
      month = cf[month_key].to_s.strip
      year = cf[year_key].to_s.strip

      # Only validate if any of the fields are present, OR if user is being created.
      # (On signup, these should be present; on existing users, we avoid blocking unrelated updates.)
      if day.blank? && month.blank? && year.blank?
        return unless new_record?
        errors.add(:base, I18n.t("hbp_birthdate.errors.missing"))
        return
      end

      if day.blank? || month.blank? || year.blank?
        errors.add(:base, I18n.t("hbp_birthdate.errors.missing"))
        return
      end

      day_i = day.to_i
      month_i = month.to_i
      year_i = year.to_i

      # Basic sanity checks
      if year_i < 1900 || year_i > Time.zone.today.year
        errors.add(:base, I18n.t("hbp_birthdate.errors.invalid_year"))
        return
      end

      date =
        begin
          Date.new(year_i, month_i, day_i)
        rescue ArgumentError
          nil
        end

      unless date
        errors.add(:base, I18n.t("hbp_birthdate.errors.invalid_date"))
        return
      end

      if date > Time.zone.today
        errors.add(:base, I18n.t("hbp_birthdate.errors.future_date"))
        return
      end

      min_age = SiteSetting.hbp_birthdate_min_age.to_i
      max_age = SiteSetting.hbp_birthdate_max_age.to_i

      age = HbpBirthdate::Birthdate.age_from_date(date)

      if min_age > 0 && age < min_age
        errors.add(:base, I18n.t("hbp_birthdate.errors.too_young", min_age: min_age))
        return
      end

      if max_age > 0 && age > max_age
        errors.add(:base, I18n.t("hbp_birthdate.errors.too_old", max_age: max_age))
        return
      end
    end
  end
end

# Hook into the User model
::User.include HbpBirthdate::UserValidator
