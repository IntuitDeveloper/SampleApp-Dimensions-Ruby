class SessionsController < ApplicationController
  def logout
    reset_session
    flash[:success] = "Successfully logged out"
    redirect_to root_path
  end
end
