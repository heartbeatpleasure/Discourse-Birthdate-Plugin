# frozen_string_literal: true

module HbpBirthdate
  class UserFields
    PLUGIN_STORE_NS = "hbp_birthdate"
    STORE_KEY = "user_field_ids"
    MIN_YEAR = 1900

    FIELD_MAP = {
      "day" => "hbp_birth_day",
      "month" => "hbp_birth_month",
      "year" => "hbp_birth_year"
    }.freeze

    # Creates/updates all 3 fields and stores their IDs in PluginStore (per environment).
    def self.ensure!
      ids = ids() # resilient: reconstruct from DB if PluginStore is empty

      day_id = ensure_field!(ids["day"], FIELD_MAP["day"], "Birth day", day_options)
      ids["day"] = day_id
      PluginStore.set(PLUGIN_STORE_NS, STORE_KEY, ids)

      month_id = ensure_field!(ids["month"], FIELD_MAP["month"], "Birth month", month_options)
      ids["month"] = month_id
      PluginStore.set(PLUGIN_STORE_NS, STORE_KEY, ids)

      year_id = ensure_field!(ids["year"], FIELD_MAP["year"], "Birth year", year_options)
      ids["year"] = year_id
      PluginStore.set(PLUGIN_STORE_NS, STORE_KEY, ids)

      set_positions!(day_id, month_id, year_id)

      ids
    end

    # Resilient: if PluginStore is empty, rebuild it from actual fields by stable machine name.
    def self.ids
      stored = PluginStore.get(PLUGIN_STORE_NS, STORE_KEY)
      stored = {} unless stored.is_a?(Hash)

      FIELD_MAP.each do |part, machine_name|
        next if stored[part].present?

        f = ::UserField.find_by(name: machine_name)
        stored[part] = f.id if f.present?
      end

      stored
    end

    def self.user_field_key_for(part)
      id = ids[part]
      return nil if id.blank?
      "user_field_#{id}"
    end

    def self.ensure_field!(existing_id, machine_name, display_name, options)
      field = find_field(existing_id, machine_name)

      if field.nil?
        field = ::UserField.new
        field.name = machine_name
        field.description = display_name
      end

      field.field_type = "dropdown"

      # Required on signup (newer Discourse uses requirement enum)
      if field.respond_to?(:requirement=)
        field.requirement = "on_signup"
      elsif field.respond_to?(:required=)
        field.required = true
      end

      # Privacy defaults
      field.show_on_profile = false if field.respond_to?(:show_on_profile=)
      field.show_on_user_card = false if field.respond_to?(:show_on_user_card=)

      # Some versions still have show_on_signup boolean
      field.show_on_signup = true if field.respond_to?(:show_on_signup=)

      # Lock editing after signup? (if setting missing, default to editable)
      if field.respond_to?(:editable=)
        lock_after = safe_site_setting(:hbp_birthdate_lock_after_signup, false)
        field.editable = !lock_after
      end

      field.save! if field.new_record? || field.changed?

      sync_dropdown_options!(field, options)

      field.id
    end

    # Only trust existing_id if it points to the correct machine name.
    def self.find_field(existing_id, machine_name)
      if existing_id.present?
        f = ::UserField.find_by(id: existing_id)
        return f if f&.name == machine_name
      end

      ::UserField.find_by(name: machine_name)
    end

    def self.sync_dropdown_options!(field, desired_options)
      desired = desired_options.map(&:to_s)

      unless field.respond_to?(:user_field_options) && defined?(::UserFieldOption)
        raise "Cannot sync dropdown options: user_field_options/UserFieldOption not available"
      end

      # Critical fix for your environment:
      # Some Discourse builds apply a default ORDER BY position on this association,
      # while the DB column `position` may not exist -> crashes on pluck.
      scope = field.user_field_options
      scope = scope.reorder(nil) if scope.respond_to?(:reorder)

      current = scope.pluck(:value)
      return if current == desired

      ::UserFieldOption.where(user_field_id: field.id).delete_all

      # Only set position if the column exists.
      has_position =
        begin
          ::UserFieldOption.column_names.include?("position")
        rescue
          false
        end

      desired.each_with_index do |val, idx|
        attrs = { user_field_id: field.id, value: val }
        attrs[:position] = idx if has_position
        ::UserFieldOption.create!(attrs)
      end
    end

    def self.set_positions!(day_id, month_id, year_id)
      return unless ::UserField.column_names.include?("position")

      fields = ::UserField.where(id: [day_id, month_id, year_id]).index_by(&:id)
      return if fields.size != 3

      base = (fields.values.map(&:position).compact.min || 0)
      fields[day_id].update_columns(position: base)
      fields[month_id].update_columns(position: base + 1)
      fields[year_id].update_columns(position: base + 2)
    end

    def self.day_options
      (1..31).map { |d| format("%02d", d) }
    end

    def self.month_options
      (1..12).map { |m| format("%02d", m) }
    end

    def self.year_options
      current_year = Time.zone.today.year

      range_years = safe_site_setting(:hbp_birthdate_year_range_years, 120).to_i
      range_years = 120 if range_years <= 0
      range_years = 200 if range_years > 200

      start_year = current_year - range_years
      start_year = MIN_YEAR if start_year < MIN_YEAR

      (start_year..current_year).to_a.reverse.map(&:to_s)
    end

    def self.safe_site_setting(name, default)
      return default unless defined?(::SiteSetting)
      return default unless ::SiteSetting.respond_to?(name)

      ::SiteSetting.public_send(name)
    rescue
      default
    end
  end
end
