# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  def edit
    @current_settings = BrandingService.settings
  end

  def update
    # Extract the uploaded file object
    uploaded_logo = params[:branding][:logo_file] # New parameter for the file

    # Prepare other settings from form parameters
    new_settings_data = {
      # We don't pass logo_path directly from a text field if we have a file upload
      # BrandingService will construct the path if a logo is uploaded.
      # If no file is uploaded, and user wants to revert to default via text field:
      logo_path: params[:branding][:logo_path_fallback], # A new field to revert to asset
      primary_color: params[:branding][:primary_color],
      text_on_primary_color: params[:branding][:text_on_primary_color],
      secondary_color: params[:branding][:secondary_color],
      text_color: params[:branding][:text_color],
      background_color: params[:branding][:background_color]
    }

    if BrandingService.update_settings(new_settings_data, uploaded_logo)
      redirect_to edit_branding_settings_path, notice: 'Branding updated successfully!'
    else
      @current_settings = BrandingService.settings
      flash.now[:alert] = 'Failed to update branding settings.'
      render :edit, status: :unprocessable_entity
    end
  end
end