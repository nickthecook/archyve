# frozen_string_literal: true

# The folder picker browses one directory at a time, because Nextcloud refuses
# `Depth: infinity` on PROPFIND — there is no call that lists a whole tree.
class Views::Sources::Forms::Nextcloud < Views::Sources::Form
  include Views::Sources::Forms::FolderPicker

  def self.new_heading = "Add a Nextcloud server"

  def self.new_blurb
    "Archyve reads the folders you pick, including everything in their subfolders, and keeps the archive matching them."
  end

  def self.edit_blurb
    "Unticking a folder doesn't delete anything you filed by hand: its files stop being fed, and the ones only this source put in a collection are retired."
  end

  private

  def type_fields
    field("Folders to sync", "Browse in and tick as many as you like. Everything inside is taken, and stays in step as files are added and removed.") do
      folder_picker
    end
  end

  def new_server_hint
    "The server, and the user Archyve reads it as. Archyve sees that user's files, plus whatever is shared with them."
  end

  # Only this type and BookStack need one: the listing comes from a live call, so
  # changing server has to re-list what is on it.
  def server_extras = browse_button

  def browse_button
    browse_to(nil, "Browse", css: button_class(:quiet, "shrink-0"))
  end

  def root_label = "All files"
  def empty_root_text = "No folders on this server."
  def catalogue_error_hint = "Check the endpoint's address, username and app password, then Browse again."
end
