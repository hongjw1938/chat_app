### Live Chat
* 필요한 것
    - 유저
    - 채팅(메세지)
    - 채팅방
    - 채팅방과 유저를 연결하는 join table
    * 필요 gem
        - pusher <a href="https://github.com/pusher/pusher-http-ruby">참조</a>
        - devise : 유저 등록 및 암호화를 위해 사용
        - figaro
        - turbolinks : 는 주석 ^^
* 구현
    * devise
        - `rails g devise:install` : 설치
        - `rails g devise users` : 유저 생성
    * scaffold
        - `rails g scaffold chat_room`
    * model
        - `rails g model chat`
        - `rails g model admission`
    * DB
        - chat_room
            - 방 제목, 방장, 현재인원, 최대 인원, 
        - chat
            - 유저(references), chat_room(references) : 이 경우는 다대다 테이블에서 참조한다는 의미
                > 모델명을 참조한다는 의미로 직관적으로 사용하는 것. 알아서 id를 참조함(*schema.rb*참조)

        - admission(join table)
            - 유저(references), chat_room(references)
    * model 관계
        - admission.rb
            - 유저 및 chat_room에 각각 belongs_to된다. admissions_count는 caching(`counter_cache: true`)
            * 모델 코딩
                - `user_joined_chat_room_notification` : user가 방에 입장하면 trigger를 발생시키는 메소드
                    - chat_room을 생성한 master는 생성하자 마자 join
                    > `Pusher.trigger("chat_room_#{self.chat_room_id}", 'join', self.as_json.merge({email: self.user.email})) ` : json으로 데이터를 전달하며 현재 입장한 방의 번호를 join이벤트로 trigger발생시킴.
                    
                - 위에서 trigger로 이벤트를 발생시킬 때 단순히 `'chat_room'`으로 하면 같은 채널만 인식하게 된다. 따라서 chat_room마다 고유의 id를 가지므로 해당 id에 따르는 경우에만 이벤트를 발생시켜야한다.
                    > `Pusher.trigger("chat_room_#{self.chat_room_id}", 'join', {chat_room_id: self.chat_room_id, email: self.user.email}) `
                 
                - `after_commit :user_exit_chat_room_notification, on: :destroy` : admission이 destroy될 때 작동
                    - 해당 메소드는 exit버튼을 누른 후, admission이 destroy될 때 작동하며, trigger를 통해 이벤트를 발생시킨다.
                    - 이 이벤트를 view에서 읽어낸 후, 현재 방에 참여한 사람의 목록에서 삭제하도록 명시한다.
        - chat.rb
            - 유저 및 chat_room에 각각 belongs_to됨.
            * 모델 코딩
                - `after_commit :chat_message_notification, on: :create` : chat이 만들어질 때 수행시킨다.
                    - 해당 메소드는 chat이 생성되었을 때 생성된 채널에 그 chat의 정보를 담아 trigger를 발생시킨다.
        - chat_room.rb
            - 여러 admission을 가진다.(`has_many :admissions`)
            - admission을 통해 여러 user를 가짐(`has_many :users, through admissions`)
            * 모델 코딩
                - user_admit_room instance method
                    - user가 방에 join시에, master가 방을 생성시에 수행된다. 수행 시기는 controller에 코딩
                    - 채팅방이 생성되자 마자 생성한 유저가 마스터가 된다.(controller에 코딩함 create action참조)
                - create_chat_room_notification method
                    - 채팅방이 개설될 때 해당 메소드가 수행된다. (`after_commit :method, on: create`)
                    - Pusher.trigger메소드에 channel_name, channel_event_name, event에 전달할 data를 지정한다.
                    - 이를 통해, 채팅방이 개설되면 특정 채널 이름에 특정 이벤트를 발생시킬 수 있다.(데이터를 전달)
                        > 해당 데이터는 Pusher객체를 만들어 key, cluster를 전달하여 구독할 수 있다.(chat_rooms/index.html.erb에 js로 구현함.)
                
                - user_exit_room method
                    - 유저가 exit버튼을 눌렀을 때, 컨트롤러에서 작동시키는 method이다.
                    - 이 메서드는 해당 user의 admission을 찾아서 destroy시킨다.
                - update_chat_room_notification
                    - chat_room의 title, max_count 등이 update되었을 때, 해당 trigger를 발생시킴.
        - user.rb
            - 여러 방에 참여(`has_many :admissions`)
            - admissions를 통하여(`has_many :chat_rooms, through: :admissions`)
            - 여러 채팅을 가진다(`has_many :chats`)
    * controller
        - chat_room.controller
            - filter
                - 로그인 되지 않으면 index이외에 아무것도 불가능 : `before_action :authenticate_user!, except: [:index]`
            - create action
                - chat_room이 생성시 master_id는 현재 유저의 아이디이다.
                    > `@chat_room.master_id = current_user.email`
                
                - `@chat_room.user_admit_room(currnet_user)`
                    > chat_room으로 만들어진 인스턴스를 통해서 모델에 코딩해놓은 인스턴스 메소드를 수행한다.
                    
                    > 해당 메소드를 수행시킬 위치는 save된 다음이다.
                    
            - user_admit_room action
                - 현재 유저가 있는 방에서 join button을 눌렀을 때 동작하는 액션
                - user_admit_room 메소드를 수행한다.
                - 당연히 set_chat_room 액션을 사전에 수행시켜 현재 접속한 chat_room의 id를 얻어와야 한다.
                - 현재 유저가 이미 join했으면 더이상 join할 수 없도록 controller 코딩한다.
                    - 이미 조인한 유저라면 alert를 띄우고 아니라면 join시킨다.
                    > `if current_user.admissions.where(chat_room_id: @chat_room.id).exists?` : 즉, 현재 방에 join되었을 시, error로 이동시킨다.
                    
                    > 혹은 => current_user.chat_rooms.include?(@chat_room)
                      또는 => @chat_room.users.include?(current_user)
                      
                - 모델 코딩을 할 경우 인스턴스 메소드로 위의 내용을 포함시킬 수 있다.
                - 만약 현재 인원이 max_count 이상일 경우 더이상 join시켜선 안된다
                    - `@chat_room.max_count <= @chat_room.admissions.size` 를 통해서 확인할 수 있다.
            - chat action
                - `@chat_room.chats.create(user_id: current_user.id, message: params[:message]);`
                - chat_room마다 chats객체를 가져와 생성함.(set_chat_room으로 @chat_room으로 쓸 수 있도록 해야한다.)
            - user_exit_room
                - user가 exit버튼을 누르면 작동(model에 코딩한 메소드 수행)
                - 방장이 나가는 경우, 남은 사람 중 랜덤하게 방장 권한을 준다.
                - 만약, 남은 사람이 0명이면, 방을 destroy하고 `root_path`로 이동시킨다.
            - is_qualified?
                - 방장인 경우에만 edit, destroy가 가능해야 한다. 이 경우를 확인하는 method
    * views
        - chat_rooms
            - index 
                -   <pre><code> var pusher = new Pusher("<%= ENV["pusher_key"] %>", {
                          cluster: "<%= ENV["pusher_cluster"] %>",
                          encrypted: true
                        }); </code></pre>
                - 위와 같이 pusher객체를 읽어올 수 있다.
                - <pre><code> 
                    var channel = pusher.subscribe('chat_room'); >> 이 부분은 원래는 id에 맞게 인식해야함.
                        channel.bind('create', function(data) {
                        console.log(data);
                    });
                </code></pre>
                - 위 코드를 통해서 subscribe함으로써 해당 보낸 데이터를 읽어올 수 있다.
                - 어떤 채널에서 어떤 이벤트가 발생하는지 대기하고 있다가 trigger가 발생하면 작동한다.
                - join이벤트가 특정 채널에 발생했을 때(유저가 채팅방에 입장한 경우) 처리하는 메소드는 다음과 같다.
                - <pre><code>
                    channel.bind('join', function(data){
                      //console.log(data);
                      user_joined(data);
                    });
                </code></pre>
                - 위 코드를 통해 user_joined함수를 가동시키고 해당 함수에서는 현재 참여중인 인원을 추가할 수 있다.
            - show
                - 채팅방에 참여한 인원의 목록을 보여줄 것이다.
                - 해당 채팅방에 join하기 위해서 route에는 현재 chat_room의 resources에서 member를 지정해 특정 chat_room의 id에 따라서 join할 수 있도록 지정한다.
                - `<%= link_to 'join', join_chat_room_path(@chat_room), method: 'post', remote: true, class: "join_room" %>`
                    > 해당 링크 태그를 통해서 remote를 통해 ajax로 동작하여 route에 따른 action을 수행시킬 수 있다.
                    
                    > 해당 링크를 누르면 user_admit_room액션이 수행되고 그에 따라 모델에 지정한 after_commit으로 user를 join trigger를 발생시킬 수 있다.
                
                - join trigger가 발생하면, user를 join시키는 메소드를 수행한다.
                - chat log 및 채팅을 구현해야 한다.
                - <pre><code>
                    <div class="chat_list">
                        <% @chat_room.chats.each do |chat| %>
                            <p><%= chat.user.email %>: <%= chat.message %><small><%= chat.created_at %></small></p>
                        <% end %>
                    </div>
                    <%= form_tag("/chat_rooms/#{@chat_room.id}/chat", remote: true) do %>
                        <%= text_field_tag :message %>
                    <% end %>
                </code></pre>
                - 위 코드를 통해서 chat_room에 해당하는 각 chatting을 가져와 유저마다 사용한 chat을 찍어준다.
                - 또한, form_tag를 통해서 채팅을 타이핑하고 enter를 누르면 작동할 수 있도록 수행한다.(`remote: true`를 통해서 ajax 통신이 되도록 지정할 수 있다.)
                - exit
                    - user가 joined된 경우 exit버튼을 보여주며, exit를 할 수 있는 링크를 생성해 놓는다.(ajax작동)
                    - ajax 작동이므로 js.erb파일을 만들어놓는다.
    * chat_app만들기 + 기본 문법 추가
        - pusher를 구글 검색하여 들어가고 github 등으로 가입
        - front - jquery, back - rails로 제작
        - `figaro install`로 figaro를 만들고 development환경을 제작함.
        - `application.yml`에 app에 관한 id, secret, key를 지정한다.
        - *config/initializers*에 pusher.rb를 만들고 `require 'pusher'`를 하고 ENV로 값을 지정한다.
        - pusher를 이용하면 ajax와 비슷하게 비동기로 외부의 서버와 통신하는 것과 같다.
            > ajax통신은 이벤트를 요청한 개인의 페이지에서만 작동한다. 그러나 pusher를 사용하면 다른 유저들에게도 event를 trigger시키고 binding할 수가 있다.
            
        - `remote: true` : form_tag와 link_to에서 사용할 수 있다. ajax 통신을 가능하게 해주는 간단한 코드
        - as_json
            - hash 타입으로 데이터를 변환해주는 메소드
        - merge
            - 사용예시
                - `a = Admission.first.as_json`
                - `a.merge({email: "aaa@aaa.aaa"})`
            - 위와 같은 방식으로 hash코드에 내용을 추가할 수 있다.
        - destroy_all : 배열을 전체 삭제함
        - model
            - dependent: destroy -> 삭제될 때 자동 삭제됨