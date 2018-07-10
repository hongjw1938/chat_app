class ChatRoom < ApplicationRecord
   has_many :admissions
   has_many :users, through: :admissions
   
   has_many :chats
   
   # create액션이 commit될 때, method수행
   after_commit :create_chat_room_notification, on: :create
   
   def create_chat_room_notification
      # self.as_json은 현재 나 자신을 json으로 보내는 것.
      Pusher.trigger('chat_room', 'create', self.as_json)
   end
   
   def user_admit_room(user)
      
         # ChatRoom이 하나 만들어 지고 나면 다음 메소드를 같이 실행
         Admission.create(user_id: user.id, chat_room_id: self.id)
      
   end
   
end
