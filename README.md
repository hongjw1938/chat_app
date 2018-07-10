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
                    > `Pusher.trigger('chat_room', 'join', {chat_room_id: self.chat_room_id}.as_json)` : json으로 데이터를 전달하며 현재 입장한 방의 번호를 join이벤트로 trigger발생시킴.
                    
        - chat.rb
            - 유저 및 chat_room에 각각 belongs_to됨.
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
                    > `if current_user.admissions.where(chat_room_id: @chat_room.id).exists?` : 즉, 현재 방에 join되었을 시, error로 이동시킨다.
                    
    * views
        - chat_rooms
            - index 
                -   <pre><code> var pusher = new Pusher("<%= ENV["pusher_key"] %>", {
                          cluster: "<%= ENV["pusher_cluster"] %>",
                          encrypted: true
                        }); </code></pre>
                - 위와 같이 pusher객체를 읽어올 수 있다.
                - <pre><code> 
                    var channel = pusher.subscribe('chat_room');
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
    * chat_app만들기
        - pusher를 구글 검색하여 들어가고 github 등으로 가입
        - front - jquery, back - rails로 제작
        - `figaro install`로 figaro를 만들고 development환경을 제작함.
        - `application.yml`에 app에 관한 id, secret, key를 지정한다.
        - *config/initializers*에 pusher.rb를 만들고 `require 'pusher'`를 하고 ENV로 값을 지정한다.
        - pusher를 이용하면 ajax와 비슷하게 비동기로 외부의 서버와 통신하는 것과 같다.