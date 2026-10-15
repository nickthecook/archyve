module Endpoints
  # A Nextcloud server, reached as one of its users with an app password. Like
  # Endpoints::Bookstack this row is an identity rather than just an address:
  # Nextcloud serves it that user's files and nothing else, so whatever it can
  # reach may end up surfaced under Archyve's access model instead of Nextcloud's.
  #
  # An app password rather than the account password: Nextcloud issues them per
  # client, they skip two-factor, and revoking one costs the user nothing else.
  class Nextcloud < Endpoint
    ACCESS_TIMEOUT = 15

    store_accessor :config, :username
    credential :app_password

    validates :base_url, presence: true
    validates :username, presence: true
    validates :app_password, presence: true

    def self.permitted_keys = super + [:username, :app_password]
    def self.form_component = Views::Settings::Endpoints::Forms::Nextcloud

    def self.type_label = "Nextcloud"

    def self.description
      "A Nextcloud server. Needs a username and an app password; Archyve sees that user's files, " \
        "including folders shared with them."
    end

    def auth_headers
      { "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{app_password}")}" }
    end

    # Every file this endpoint reads hangs off one user's DAV root, so the
    # username is part of the address and not only of the credentials.
    def dav_root = "/remote.php/dav/files/#{ERB::Util.url_encode(username)}"

    def dav(timeout: DEFAULT_TIMEOUT) = ::Nextcloud::Dav.new(self, timeout: timeout)

    # The cheapest call that proves both halves: the credentials are accepted,
    # and they belong to the user whose root we are about to read.
    def access! = dav(timeout: ACCESS_TIMEOUT).exist?
  end
end
