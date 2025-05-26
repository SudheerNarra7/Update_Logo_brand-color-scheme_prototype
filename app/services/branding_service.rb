# app/services/branding_service.rb
require 'yaml'
require 'fileutils' # Required for FileUtils.mkdir_p

class BrandingService
  SETTINGS_FILE = Rails.root.join('config', 'branding_settings.yml')
  PUBLIC_UPLOADS_SUBDIR = 'uploads/logos'.freeze # Relative to public path
  CUSTOM_LOGO_FILENAME = 'custom_site_logo.png'.freeze # Fixed filename for uploaded logo

  @settings = nil

  def self.load_settings
    defaults = {
      logo_path: "default_site_logo.png", # Points to app/assets/images/
      primary_color: "#343A40",
      text_on_primary_color: "#FFFFFF",
      secondary_color: "#007BFF",
      text_color: "#212529",
      background_color: "#F8F9FA"
    }
    if File.exist?(SETTINGS_FILE)
      loaded_settings = YAML.load_file(SETTINGS_FILE)&.deep_symbolize_keys || {}
      @settings = defaults.merge(loaded_settings)
    else
      @settings = defaults
      File.write(SETTINGS_FILE, @settings.deep_stringify_keys.to_yaml)
    end
  rescue Psych::SyntaxError => e
    Rails.logger.error "BrandingService: Error parsing YAML file: #{e.message}. Using default settings."
    @settings = defaults
  end

  load_settings

  def self.settings
    load_settings if @settings.nil?
    @settings
  end

  def self.update_settings(new_settings_hash, uploaded_logo_file = nil)
    load_settings if @settings.nil?
    current_settings = @settings.dup
    new_settings_params = new_settings_hash.deep_symbolize_keys

    # Handle logo upload first
    if uploaded_logo_file.present?
      begin
        # Define the path for storing the custom logo in public/uploads/logos/
        public_dir_path = Rails.root.join('public', PUBLIC_UPLOADS_SUBDIR)
        FileUtils.mkdir_p(public_dir_path) unless File.directory?(public_dir_path)
        
        # Use a fixed filename for the custom logo to simplify things
        custom_logo_full_path = public_dir_path.join(CUSTOM_LOGO_FILENAME)
        
        File.open(custom_logo_full_path, 'wb') do |file|
          file.write(uploaded_logo_file.read)
        end
        # Update the logo_path to point to this new public file
        current_settings[:logo_path] = "/#{PUBLIC_UPLOADS_SUBDIR}/#{CUSTOM_LOGO_FILENAME}"
      rescue StandardError => e
        Rails.logger.error "BrandingService: Failed to save uploaded logo: #{e.message}"
        # Optionally, don't update YAML if logo save fails, or handle error appropriately
        # For now, we'll proceed to update other settings even if logo fails.
      end
    elsif new_settings_params.key?(:logo_path) && new_settings_params[:logo_path].blank?
      # If logo_path is submitted as blank, revert to default (or handle as needed)
      current_settings[:logo_path] = defaults[:logo_path] # Assuming 'defaults' is accessible or use literal
    elsif new_settings_params.key?(:logo_path) && new_settings_params[:logo_path].present?
       # If a filename is typed and no file uploaded, and it's different
       current_settings[:logo_path] = new_settings_params[:logo_path]
    end

    # Update other settings
    [:primary_color, :text_on_primary_color, :secondary_color, :text_color, :background_color].each do |key|
      current_settings[key] = new_settings_params[key] if new_settings_params.key?(key) && new_settings_params[key].present?
    end

    File.write(SETTINGS_FILE, current_settings.deep_stringify_keys.to_yaml)
    load_settings # Reload settings into memory
    true
  rescue StandardError => e
    Rails.logger.error "BrandingService: Failed to update branding settings: #{e.message}"
    false
  end

  # Convenience accessors
  def self.method_missing(method_name, *arguments, &block)
    load_settings if @settings.nil?
    if @settings&.key?(method_name)
      @settings[method_name]
    else
      # If trying to access a specific setting like logo_path directly
      if @settings.nil? && method_name == :logo_path # Check method_name directly
        return defaults[:logo_path] # Fallback if settings not loaded yet
      end
      super
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    load_settings if @settings.nil?
    @settings&.key?(method_name) || super
  end
  
  # Add a specific accessor for logo_path to ensure it always returns something valid
  def self.logo_path
    load_settings if @settings.nil?
    @settings[:logo_path].presence || "default_site_logo.png"
  end
end