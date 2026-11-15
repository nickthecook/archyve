# frozen_string_literal: true

class Views::Sources::Forms::Sharepoint < Views::Sources::Form
  include Views::Sources::Forms::FolderPicker

  def self.new_heading = "Add a SharePoint library"

  def self.new_blurb
    "Archyve reads the folders you pick, including everything in their subfolders, and keeps the archive matching them."
  end

  def self.edit_blurb
    "Unticking a folder doesn't delete anything you filed by hand: its files stop being fed, and the ones only this source put in a collection are retired."
  end

  private

  def type_fields
    field("Library", "Which of the site's document libraries to read. If you pick a different one, press Browse beside it to list its folders.") do
      library_picker
    end

    field("Folders to sync", "Browse in and tick as many as you like. Everything inside is taken, and stays in step as files are added and removed.") do
      folder_picker
    end
  end

  def new_server_hint = "The SharePoint site, and the app registration Archyve reads it as."

  def server_extras = browse_button

  def browse_button
    browse_to(nil, "Browse", css: button_class(:quiet, "shrink-0"))
  end

  def library_picker
    return if drives.empty?

    div(class: "flex items-center gap-2") do
      select(name: "source[drive_id]", class: input_classes) do
        drives.each do |drive|
          option(value: drive.id, selected: drive.id == @catalogue.drive_id) { drive.name }
        end
      end
      browse_button
    end
  end

  def drives = @catalogue&.drives || []

  def root_label = drives.find { |drive| drive.id == @catalogue&.drive_id }&.name || "Library"
  def empty_root_text = "No folders in this library."

  def catalogue_error_hint
    "Check the endpoint's site address, and that its app registration has been granted this site, then Browse again."
  end
end
