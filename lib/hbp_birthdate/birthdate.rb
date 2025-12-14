# frozen_string_literal: true

module HbpBirthdate
  class Birthdate
    def self.date_for(user)
      ids = HbpBirthdate::UserFields.ids
      return nil if ids.blank?

      cf = user.custom_fields || {}

      day = cf["user_field_#{ids["day"]}"].to_i
      month = cf["user_field_#{ids["month"]}"].to_i
      year = cf["user_field_#{ids["year"]}"].to_i

      return nil if day <= 0 || month <= 0 || year <= 0

      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def self.age_for(user)
      d = date_for(user)
      return nil unless d
      age_from_date(d)
    end

    def self.age_from_date(date)
      today = Time.zone.today
      age = today.year - date.year
      had_birthday = (today.month > date.month) || (today.month == date.month && today.day >= date.day)
      had_birthday ? age : age - 1
    end

    def self.birthday_today?(user)
      d = date_for(user)
      return false unless d
      today = Time.zone.today
      today.month == d.month && today.day == d.day
    end
  end
end
