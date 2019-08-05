class MessagesController < ApplicationController
  before_action :logged_in_user
  before_action :get_messages

  def index
    session[:conversations] ||= []

    @users = User.all.where.not(id: current_user)
    @conversations = Conversation.includes(:recipient, :messages)
                                 .find(session[:conversations])
  end

  def create
    @conversation = Conversation.includes(:recipient).find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)

    if @message.save
      recipient_id = @conversation.opposed_user(current_user).id
      ActionCable.server.broadcast "room_channel_user_#{recipient_id}",
                                   content:  @message.content,
                                   username: @message.user.username,
                                   conversation: @conversation.id

      @message.mentions.each do |mention|
        ActionCable.server.broadcast "room_channel_user_#{mention.id}",
                                     mention: true
      end

      respond_to do |format|
        format.js
      end
    end
  end

  private

    def get_messages
      @messages = Message.for_display
      @message  = current_user.messages.build
    end

    def message_params
      params.require(:message).permit(:content, :user_id)
    end

    def render_message(message)
      render(partial: 'message', locals: { message: @message })
    end
end
