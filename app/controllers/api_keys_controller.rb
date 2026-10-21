class ApiKeysController < ApplicationController
  def create
    api_key = Current.user.api_keys.create(name: params[:name])

    if api_key.persisted?
      redirect_to account_path, flash: { api_key_token: api_key.token }
    else
      redirect_to account_path, alert: api_key.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.user.api_keys.find(params[:id]).destroy
    redirect_to account_path, notice: "API key deleted. Anything using it can no longer reach the API."
  end
end
