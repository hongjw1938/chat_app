class Admission < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room, counter_cache: true
    
    after_commit :user_joined_chat_room_notification, on: :create
    
    def user_joined_chat_room_notification
       # 어느 방에 join했는가
       Pusher.trigger('chat_room', 'join', {chat_room_id: self.chat_room_id, email: self.user.email}) 
    end
end

