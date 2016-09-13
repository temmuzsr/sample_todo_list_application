class UsersController < ApplicationController

  def update
    respond_to do |format|
      if @user.update(user_params)
        sign_in(@user == current_user ? @user : current_user, :bypass => true)
        format.html { redirect_to @user, notice: 'Your profile was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end


  def finish_sign_up
    @user = User.find(params[:id])
    @email = 
      if params[:user].present? 
        params[:user][:email]
      elsif
        params[:email].present?
        params[:email]
      end
    if @email.present?
      @user.email = @email
      @user.skip_reconfirmation!
      if @user.save
        sign_in(@user, :bypass => true)
        redirect_to root_path, notice: 'Your profile was successfully updated.'
      else
        @show_errors = true
      end
    end
  end

  def destroy
    @user.destroy
    respond_to do |format|
      format.html { redirect_to root_url }
      format.json { head :no_content }
    end
  end
  
  private
    def user_params
      params.require(:user).permit(:name, :email)
    end
end