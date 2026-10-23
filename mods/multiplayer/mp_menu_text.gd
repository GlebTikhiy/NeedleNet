extends RefCounted

const TEXT := {
	"en": {"hint": "Co-op for up to %d players", "host": "Hosting · %d/%d players", "guest": "In a session · %d/%d players", "free": "Open slot", "invite": "Invite a friend", "connecting": "Connecting…", "session": "SESSION", "tooltip": "Create a session, invite friends and choose a save."},
	"ru": {"hint": "Кооператив до %d игроков", "host": "Вы — хост · %d/%d игроков", "guest": "В сессии · %d/%d игроков", "free": "Свободное место", "invite": "Пригласите друга", "connecting": "Подключение…", "session": "СЕССИЯ", "tooltip": "Создайте сессию, пригласите друзей и выберите сохранение."},
	"de": {"hint": "Koop für bis zu %d Spieler", "host": "Gastgeber · %d/%d Spieler", "guest": "In einer Sitzung · %d/%d Spieler", "free": "Freier Platz", "invite": "Freund einladen", "connecting": "Verbinden…", "session": "SITZUNG", "tooltip": "Sitzung erstellen, Freunde einladen und Spielstand wählen."},
	"es": {"hint": "Cooperativo para hasta %d jugadores", "free": "Plaza libre", "invite": "Invita a un amigo", "connecting": "Conectando…", "session": "SESIÓN"},
	"fr": {"hint": "Coop jusqu’à %d joueurs", "free": "Place libre", "invite": "Invitez un ami", "connecting": "Connexion…", "session": "SESSION"},
	"it": {"hint": "Cooperativa fino a %d giocatori", "free": "Posto libero", "invite": "Invita un amico", "connecting": "Connessione…", "session": "SESSIONE"},
	"cs": {"hint": "Kooperace až pro %d hráče", "free": "Volné místo", "invite": "Pozvěte přítele", "connecting": "Připojování…", "session": "RELACE"},
	"pl": {"hint": "Kooperacja do %d graczy", "free": "Wolne miejsce", "invite": "Zaproś znajomego", "connecting": "Łączenie…", "session": "SESJA"},
	"uk": {"hint": "Кооператив до %d гравців", "free": "Вільне місце", "invite": "Запросіть друга", "connecting": "Підключення…", "session": "СЕСІЯ"},
	"pt": {"hint": "Cooperativo para até %d jogadores", "free": "Vaga livre", "invite": "Convide um amigo", "connecting": "Conectando…", "session": "SESSÃO"},
	"tr": {"hint": "%d oyuncuya kadar eşli oyun", "free": "Boş yer", "invite": "Arkadaşını davet et", "connecting": "Bağlanıyor…", "session": "OTURUM"},
	"ja": {"hint": "最大%d人の協力プレイ", "free": "空きスロット", "invite": "フレンドを招待", "connecting": "接続中…", "session": "セッション"},
	"ko": {"hint": "최대 %d인 협동 플레이", "free": "빈자리", "invite": "친구 초대", "connecting": "연결 중…", "session": "세션"},
	"zh": {"hint": "最多%d人合作", "free": "空位", "invite": "邀请好友", "connecting": "连接中…", "session": "会话"},
	"zh_TW": {"hint": "最多%d人合作", "free": "空位", "invite": "邀請好友", "connecting": "連線中…", "session": "連線遊戲"},
	"ar": {"hint": "لعب تعاوني حتى %d لاعبين", "free": "مكان شاغر", "invite": "دعوة صديق", "connecting": "جارٍ الاتصال…", "session": "الجلسة"},
	"fa": {"hint": "بازی گروهی تا %d بازیکن", "free": "جای خالی", "invite": "دعوت از دوست", "connecting": "در حال اتصال…", "session": "نشست"}
}

static func text(key: String, language: String) -> String:
	return str(TEXT.get(language, TEXT.en).get(key, TEXT.en.get(key, key)))
