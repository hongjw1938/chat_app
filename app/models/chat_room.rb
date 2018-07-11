class ChatRoom < ApplicationRecord
   has_many :admissions, dependent: :destroy
   has_many :users, through: :admissions
   
   has_many :chats
   
   # create액션이 commit될 때, method수행
   after_commit :create_chat_room_notification, on: :create
   after_commit :update_chat_room_notification, on: :update
   after_commit :destroy_chat_room_notification, on: :destroy
   
   def create_chat_room_notification
      # self.as_json은 현재 나 자신을 json으로 보내는 것.
      Pusher.trigger("chat_room_#{self.id}", 'create', self.as_json)
      Pusher.trigger("chat_room", 'create', self.as_json)
   end
   
   def user_admit_room(user)
      
         # ChatRoom이 하나 만들어 지고 나면 다음 메소드를 같이 실행
         Admission.create(user_id: user.id, chat_room_id: self.id)
      
   end
   
   def user_exit_room(user)
      Admission.where(user_id: user.id, chat_room_id: self.id)[0].destroy
   end
   
   def destroy_chat_room_notification
      Pusher.trigger('chat_room', 'destroy', self.as_json)
      Pusher.trigger("chat_room_#{self.id}", 'destroy', {})
        
   end
   
   def update_chat_room_notification
      Pusher.trigger('chat_room', 'update', self.as_json)
   end
   
end
