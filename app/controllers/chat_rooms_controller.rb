class ChatRoomsController < ApplicationController
  before_action :set_chat_room, only: [:show, :edit, :update, :destroy, :user_admit_room, :chat, :user_exit_room]
  before_action :authenticate_user!, except: [:index]
  before_action :is_qualified?, only: [:edit, :destroy]
  

  # GET /chat_rooms
  # GET /chat_rooms.json
  def index
    @chat_rooms = ChatRoom.all
  end

  # GET /chat_rooms/1
  # GET /chat_rooms/1.json
  def show
  end

  # GET /chat_rooms/new
  def new
    @chat_room = ChatRoom.new
  end

  # GET /chat_rooms/1/edit
  def edit
    
  end

  # POST /chat_rooms
  # POST /chat_rooms.json
  def create
    
    @chat_room = ChatRoom.new(chat_room_params)
    @chat_room.master_id = current_user.email

    respond_to do |format|
      if @chat_room.save
        @chat_room.user_admit_room(current_user)
        
        format.html { redirect_to @chat_room, notice: 'Chat room was successfully created.' }
        format.json { render :show, status: :created, location: @chat_room }
      else
        format.html { render :new }
        format.json { render json: @chat_room.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /chat_rooms/1
  # PATCH/PUT /chat_rooms/1.json
  def update
    respond_to do |format|
      if @chat_room.update(chat_room_params)
        
        format.html { redirect_to @chat_room, notice: 'Chat room was successfully updated.' }
        format.json { render :show, status: :ok, location: @chat_room }
      else
        format.html { render :edit }
        format.json { render json: @chat_room.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /chat_rooms/1
  # DELETE /chat_rooms/1.json
  def destroy
    @chat_room.destroy
  end
  
  def is_qualified?
    unless current_user.email.eql?(@chat_room.master_id)
      redirect_to :back, flash: {error: '방장이 아니므로 권한이 없습니다.'}
    else
      return true
    end
  end

  def user_admit_room
    
    # puts @chat_room.admissions.size
    # 현재 유저가 있는 방에서 join button을 눌렀을 때 동작하는 액션
    # 이미 조인되어 있는 유저라면?!
    # alert를 띄우고 아닐 경우에는 참가시킨다.
    
    # if current_user.admissions.where(chat_room_id: @chat_room.id).exists?
    # 이미 조인되어 있는 유저일 때, 유저가 참가하고 있는 방의 목록중에 이 방이 포함되어 있는가?
    if current_user.joined_room?(@chat_room)
      # 혹은 => current_user.chat_rooms.include?(@chat_room)
      # 또는 => @chat_room.users.include?(current_user)
      render js: "alert('이미 참여한 방입니다.')"
    elsif @chat_room.max_count <= @chat_room.admissions.size
      render js: "alert('더 이상 입장할 수 없습니다.')"
    else
      @chat_room.user_admit_room(current_user)
    end
    
  end
  
  def chat
    @chat_room.chats.create(user_id: current_user.id, message: params[:message]);
  end
  
  def user_exit_room
    @chat_room.user_exit_room(current_user)
    
    if current_user.is_room_master?(@chat_room)
      puts @chat_room.users.size
      if @chat_room.users.size > 0
        @chat_room.update(master_id: @chat_room.users.sample.email)
      else
        @chat_room.destroy
        redirect_to root_path
      end
    end
    
  end
  
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_chat_room
      @chat_room = ChatRoom.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def chat_room_params
      params.fetch(:chat_room, {}).permit(:title, :max_count)
    end
end
