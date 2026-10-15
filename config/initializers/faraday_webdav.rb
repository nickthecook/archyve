# Faraday allows only the eight standard verbs. PROPFIND is how Nextcloud lists a
# directory, and its net_http adapter builds requests through
# Net::HTTPGenericRequest, so registering the verb is all that is needed.
Faraday::Connection::METHODS << :propfind
