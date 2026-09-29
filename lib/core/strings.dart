import 'package:flutter/widgets.dart';

/// Hand-maintained translations. Add a language by adding its code to
/// [Strings.languages] and a column to every entry in [_t]
/// (`test/strings_test.dart` checks every row is complete).
class Strings {
  Strings(this.code);

  final String code;

  static const List<String> languages = ['en', 'es', 'fr', 'de', 'pt', 'ja'];

  /// Each language named in itself, for the language picker.
  static const Map<String, String> nativeNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'ja': '日本語',
  };

  static Strings of(BuildContext context) => Localizations.of<Strings>(context, Strings) ?? Strings('en');

  static const LocalizationsDelegate<Strings> delegate = _Delegate();

  /// Test hook.
  static Map<String, List<String>> get table => _t;

  String _get(String key) {
    final row = _t[key];
    assert(row != null, 'Missing string "$key"');
    if (row == null) return key;
    return row[languages.indexOf(code)];
  }

  String _n(String key, Object n) => _get(key).replaceAll('{n}', '$n');

  String get tagline => _get('tagline');
  String get play => _get('play');
  String get maps => _get('maps');
  String get store => _get('store');
  String get skins => _get('skins');
  String get upgradesTab => _get('upgrades');
  String get coinsTab => _get('coinsTab');
  String get missions => _get('missions');
  String get settings => _get('settings');
  String get close => _get('close');
  String get claim => _get('claim');
  String get claimDouble => _get('claimDouble');
  String get comeBackTomorrow => _get('comeBackTomorrow');
  String get dailyGift => _get('dailyGift');
  String day(int n) => _n('day', n);
  String get freeCoins => _get('freeCoins');
  String get videoUnavailable => _get('videoUnavailable');
  String get notEnoughCoins => _get('notEnoughCoins');
  String level(int n) => _n('level', n);
  String get max => _get('max');
  String get use => _get('use');
  String get inUse => _get('inUse');
  String reachLevel(int n) => _n('reachLevel', n);
  String get watchToUnlock => _get('watchToUnlock');
  String get locked => _get('locked');

  // Settings.
  String get sound => _get('sound');
  String get music => _get('music');
  String get haptics => _get('haptics');
  String get language => _get('language');
  String get deviceLanguage => _get('deviceLanguage');
  String get privacy => _get('privacy');
  String get rateUs => _get('rateUs');
  String get restorePurchases => _get('restorePurchases');
  String get howToPlay => _get('howToPlay');
  String get version => _get('version');

  // Round.
  String get you => _get('you');
  String get ready => _get('ready');
  String get go => _get('go');
  String get size => _get('size');
  String get paused => _get('paused');
  String get resume => _get('resume');
  String get leaveRound => _get('leaveRound');
  String get leaveWarning => _get('leaveWarning');
  String get yum => _get('yum');
  String get gulp => _get('gulp');
  String get huge => _get('huge');
  String get combo => _get('combo');
  String get hintMove => _get('hintMove');
  String get hintEat => _get('hintEat');
  String get hintMedium => _get('hintMedium');
  String get hintLarge => _get('hintLarge');
  String get hintBuilding => _get('hintBuilding');
  String get hintAvoid => _get('hintAvoid');
  String get hintSpeed => _get('hintSpeed');
  String get hintMagnet => _get('hintMagnet');
  String get hintFrenzy => _get('hintFrenzy');
  String ateRival(String name) => _get('ateRival').replaceAll('{name}', name);

  // Eaten.
  String eatenBy(String name) => _get('eatenBy').replaceAll('{name}', name);
  String get revive => _get('revive');
  String get noThanks => _get('noThanks');

  // Results.
  String get winner => _get('winner');
  String place(int n, int of) => _get('place').replaceAll('{n}', '$n').replaceAll('{m}', '$of');
  String get people => _get('people');
  String get things => _get('things');
  String get monsters => _get('monsters');
  String get maxSize => _get('maxSize');
  String get newBest => _get('newBest');
  String get doubleCoins => _get('doubleCoins');
  String get playAgain => _get('playAgain');
  String get home => _get('home');
  String get newMapUnlocked => _get('newMapUnlocked');
  String levelUp(int n) => _n('levelUp', n);
  String get xp => _get('xp');
  String get missionProgress => _get('missionProgress');

  // Missions.
  String get dailyMissions => _get('dailyMissions');
  String get allDoneBonus => _get('allDoneBonus');
  String get swap => _get('swap');
  String get done => _get('done');
  String newMissionsIn(String t) => _get('newMissionsIn').replaceAll('{t}', t);

  String mission(String kind, int n) => switch (kind) {
    'reachSize' => _get('m_reachSize').replaceAll('{n}', (n / 10).toStringAsFixed(1)),
    _ => _n('m_$kind', n),
  };

  // Wheel.
  String get luckyWheel => _get('luckyWheel');
  String get spin => _get('spin');
  String get spinAgain => _get('spinAgain');
  String freeSpinIn(String t) => _get('freeSpinIn').replaceAll('{t}', t);
  String spinsLeft(int n) => _n('spinsLeft', n);
  String get youWon => _get('youWon');

  // Store.
  String get removeAds => _get('removeAds');
  String get removeAdsDesc => _get('removeAdsDesc');
  String get adsRemoved => _get('adsRemoved');
  String get coinPacks => _get('coinPacks');
  String get storeUnavailable => _get('storeUnavailable');
  String get purchaseThanks => _get('purchaseThanks');
  String get purchaseFailed => _get('purchaseFailed');
  String get bestValue => _get('bestValue');

  // Maps.
  String coinsX(double n) => _get('coinsX').replaceAll('{n}', n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2));
  String rivals(int n) => _n('rivals', n);
  String best(String metres) => _get('bestSize').replaceAll('{n}', metres);
  String wins(int n) => _n('wins', n);

  String mapName(String id) => _get('map_$id');
  String upgradeName(String id) => _get('up_$id');
  String upgradeDesc(String id) => _get('updesc_$id');

  static const Map<String, List<String>> _t = {
    //                en, es, fr, de, pt, ja
    'tagline': [
      'Gobble the town. Grow HUGE!',
      '¡Devora la ciudad y crece ENORME!',
      'Dévore la ville. Deviens ÉNORME !',
      'Friss die Stadt. Werde RIESIG!',
      'Devore a cidade. Fique ENORME!',
      '街を食べつくして巨大化しよう！',
    ],
    'play': ['Play', 'Jugar', 'Jouer', 'Spielen', 'Jogar', 'プレイ'],
    'maps': ['Maps', 'Mapas', 'Cartes', 'Karten', 'Mapas', 'マップ'],
    'store': ['Store', 'Tienda', 'Boutique', 'Laden', 'Loja', 'ストア'],
    'skins': ['Monsters', 'Monstruos', 'Monstres', 'Monster', 'Monstros', 'モンスター'],
    'upgrades': ['Upgrades', 'Mejoras', 'Améliorations', 'Upgrades', 'Melhorias', '強化'],
    'coinsTab': ['Coins', 'Monedas', 'Pièces', 'Münzen', 'Moedas', 'コイン'],
    'missions': ['Missions', 'Misiones', 'Missions', 'Missionen', 'Missões', 'ミッション'],
    'settings': ['Settings', 'Ajustes', 'Réglages', 'Einstellungen', 'Configurações', '設定'],
    'close': ['Close', 'Cerrar', 'Fermer', 'Schließen', 'Fechar', '閉じる'],
    'claim': ['Claim', 'Recoger', 'Récupérer', 'Abholen', 'Coletar', '受け取る'],
    'claimDouble': ['Claim x2', 'Recoger x2', 'Récupérer x2', 'x2 abholen', 'Coletar x2', '2倍で受け取る'],
    'comeBackTomorrow': [
      'Come back tomorrow for the next gift!',
      '¡Vuelve mañana por el siguiente regalo!',
      'Reviens demain pour le prochain cadeau !',
      'Komm morgen für das nächste Geschenk wieder!',
      'Volte amanhã para o próximo presente!',
      '明日また来てプレゼントをもらおう！',
    ],
    'dailyGift': ['Daily Gift', 'Regalo diario', 'Cadeau du jour', 'Tagesgeschenk', 'Presente diário', 'デイリーギフト'],
    'day': ['Day {n}', 'Día {n}', 'Jour {n}', 'Tag {n}', 'Dia {n}', '{n}日目'],
    'freeCoins': ['Free coins', 'Monedas gratis', 'Pièces gratuites', 'Gratis-Münzen', 'Moedas grátis', '無料コイン'],
    'videoUnavailable': [
      'No video right now. Try again soon!',
      'No hay vídeo ahora. ¡Inténtalo pronto!',
      'Pas de vidéo pour le moment. Réessaie bientôt !',
      'Gerade kein Video. Versuch es gleich nochmal!',
      'Nenhum vídeo agora. Tente de novo em breve!',
      '今は動画がありません。少し後でお試しください！',
    ],
    'notEnoughCoins': [
      'Not enough coins',
      'No tienes suficientes monedas',
      'Pas assez de pièces',
      'Nicht genug Münzen',
      'Moedas insuficientes',
      'コインが足りません',
    ],
    'level': ['Lv {n}', 'Nv {n}', 'Niv. {n}', 'Lv {n}', 'Nv {n}', 'Lv {n}'],
    'max': ['MAX', 'MÁX', 'MAX', 'MAX', 'MÁX', 'MAX'],
    'use': ['Use', 'Usar', 'Choisir', 'Wählen', 'Usar', '使う'],
    'inUse': ['In use', 'En uso', 'Choisi', 'Aktiv', 'Em uso', '使用中'],
    'reachLevel': ['Level {n}', 'Nivel {n}', 'Niveau {n}', 'Level {n}', 'Nível {n}', 'レベル{n}'],
    'watchToUnlock': [
      'Watch videos to unlock',
      'Mira vídeos para desbloquear',
      'Regarde des vidéos pour débloquer',
      'Videos ansehen zum Freischalten',
      'Assista vídeos para desbloquear',
      '動画を見て解放',
    ],
    'locked': ['Locked', 'Bloqueado', 'Verrouillé', 'Gesperrt', 'Bloqueado', 'ロック中'],
    'sound': ['Sound', 'Sonido', 'Son', 'Ton', 'Som', 'サウンド'],
    'music': ['Music', 'Música', 'Musique', 'Musik', 'Música', '音楽'],
    'haptics': ['Vibration', 'Vibración', 'Vibration', 'Vibration', 'Vibração', '振動'],
    'language': ['Language', 'Idioma', 'Langue', 'Sprache', 'Idioma', '言語'],
    'deviceLanguage': [
      'Device language',
      'Idioma del dispositivo',
      "Langue de l'appareil",
      'Gerätesprache',
      'Idioma do aparelho',
      '端末の言語',
    ],
    'privacy': [
      'Ad privacy choices',
      'Privacidad de anuncios',
      'Confidentialité des annonces',
      'Werbe-Datenschutz',
      'Privacidade dos anúncios',
      '広告のプライバシー設定',
    ],
    'rateUs': ['Rate EatUp', 'Valora EatUp', 'Noter EatUp', 'EatUp bewerten', 'Avalie o EatUp', 'EatUpを評価'],
    'restorePurchases': [
      'Restore purchases',
      'Restaurar compras',
      'Restaurer les achats',
      'Käufe wiederherstellen',
      'Restaurar compras',
      '購入を復元',
    ],
    'howToPlay': ['How to play', 'Cómo jugar', 'Comment jouer', 'So wird gespielt', 'Como jogar', '遊び方'],
    'version': ['Version', 'Versión', 'Version', 'Version', 'Versão', 'バージョン'],
    'you': ['You', 'Tú', 'Toi', 'Du', 'Você', 'あなた'],
    'ready': ['Ready?', '¿Listo?', 'Prêt ?', 'Bereit?', 'Pronto?', '準備はいい？'],
    'go': ['EAT!', '¡A COMER!', 'MANGE !', 'FRISS!', 'COMA!', 'たべろ！'],
    'size': ['Size', 'Tamaño', 'Taille', 'Größe', 'Tamanho', 'サイズ'],
    'paused': ['Paused', 'Pausa', 'Pause', 'Pause', 'Pausado', '一時停止'],
    'resume': ['Resume', 'Seguir', 'Reprendre', 'Weiter', 'Continuar', '再開'],
    'leaveRound': ['Leave round', 'Salir', 'Quitter', 'Runde verlassen', 'Sair', 'ラウンドをやめる'],
    'leaveWarning': [
      "You'll lose this round's rewards.",
      'Perderás las recompensas de esta ronda.',
      'Tu perdras les récompenses de cette manche.',
      'Du verlierst die Belohnungen dieser Runde.',
      'Você perderá as recompensas desta rodada.',
      'このラウンドの報酬はもらえません。',
    ],
    'yum': ['Yum!', '¡Ñam!', 'Miam !', 'Mjam!', 'Nham!', 'うまい！'],
    'gulp': ['Gulp!', '¡Glup!', 'Gloups !', 'Schluck!', 'Glup!', 'ゴクン！'],
    'huge': ['HUGE!', '¡ENORME!', 'ÉNORME !', 'RIESIG!', 'ENORME!', 'デカい！'],
    'combo': ['Combo x{n}', 'Combo x{n}', 'Combo x{n}', 'Combo x{n}', 'Combo x{n}', '{n}コンボ'],
    'hintMove': [
      'Drag anywhere to move',
      'Arrastra en cualquier parte para moverte',
      "Glisse n'importe où pour bouger",
      'Zieh irgendwo, um dich zu bewegen',
      'Arraste em qualquer lugar para mover',
      'どこでもドラッグして移動',
    ],
    'hintEat': [
      'Eat anything smaller than you!',
      '¡Come todo lo que sea más pequeño que tú!',
      'Mange tout ce qui est plus petit que toi !',
      'Friss alles, was kleiner ist als du!',
      'Coma tudo que for menor que você!',
      '自分より小さいものは全部食べられる！',
    ],
    'hintMedium': [
      'Big enough for trees and cars!',
      '¡Ya puedes comer árboles y coches!',
      'Assez gros pour les arbres et les voitures !',
      'Groß genug für Bäume und Autos!',
      'Já dá para comer árvores e carros!',
      '木や車も食べられるサイズに！',
    ],
    'hintLarge': [
      'Buses and fountains are on the menu!',
      '¡Autobuses y fuentes al menú!',
      'Bus et fontaines au menu !',
      'Busse und Brunnen stehen auf dem Speiseplan!',
      'Ônibus e fontes no cardápio!',
      'バスや噴水も食べられる！',
    ],
    'hintBuilding': [
      'Now eat the buildings!',
      '¡Ahora cómete los edificios!',
      'Maintenant, mange les bâtiments !',
      'Jetzt friss die Gebäude!',
      'Agora coma os prédios!',
      '建物を食べちゃおう！',
    ],
    'hintAvoid': [
      'Run from bigger monsters!',
      '¡Huye de los monstruos más grandes!',
      'Fuis les monstres plus gros !',
      'Lauf vor größeren Monstern weg!',
      'Fuja dos monstros maiores!',
      '大きなモンスターから逃げて！',
    ],
    'hintSpeed': ['Speed boost!', '¡Supervelocidad!', 'Turbo !', 'Turbo!', 'Turbo!', 'スピードアップ！'],
    'hintMagnet': ['Magnet mouth!', '¡Boca imán!', 'Bouche aimant !', 'Magnetmaul!', 'Boca ímã!', 'マグネット！'],
    'hintFrenzy': [
      'Double growth!',
      '¡Crecimiento doble!',
      'Croissance x2 !',
      'Doppeltes Wachstum!',
      'Crescimento x2!',
      '成長2倍！',
    ],
    'ateRival': [
      'You ate {name}!',
      '¡Te comiste a {name}!',
      'Tu as mangé {name} !',
      'Du hast {name} gefressen!',
      'Você comeu {name}!',
      '{name}を食べた！',
    ],
    'eatenBy': [
      '{name} ate you!',
      '¡{name} te comió!',
      '{name} t’a mangé !',
      '{name} hat dich gefressen!',
      '{name} comeu você!',
      '{name}に食べられた！',
    ],
    'revive': ['Revive', 'Revivir', 'Revivre', 'Wiederbeleben', 'Reviver', '復活'],
    'noThanks': ['No thanks', 'No, gracias', 'Non merci', 'Nein danke', 'Não, obrigado', 'やめておく'],
    'winner': ['WINNER!', '¡GANASTE!', 'VICTOIRE !', 'SIEG!', 'VITÓRIA!', '優勝！'],
    'place': ['#{n} of {m}', '#{n} de {m}', '#{n} sur {m}', '#{n} von {m}', '#{n} de {m}', '{m}体中{n}位'],
    'people': ['People', 'Personas', 'Passants', 'Leute', 'Pessoas', '人'],
    'things': ['Things', 'Cosas', 'Objets', 'Dinge', 'Coisas', 'モノ'],
    'monsters': ['Monsters', 'Monstruos', 'Monstres', 'Monster', 'Monstros', 'モンスター'],
    'maxSize': ['Max size', 'Tamaño máx.', 'Taille max', 'Max. Größe', 'Tamanho máx.', '最大サイズ'],
    'newBest': ['New best!', '¡Nuevo récord!', 'Nouveau record !', 'Neuer Rekord!', 'Novo recorde!', '自己ベスト！'],
    'doubleCoins': ['x2 Coins', 'x2 Monedas', 'x2 Pièces', 'x2 Münzen', 'x2 Moedas', 'コイン2倍'],
    'playAgain': ['Play again', 'Otra vez', 'Rejouer', 'Nochmal', 'Jogar de novo', 'もう一度'],
    'home': ['Home', 'Inicio', 'Accueil', 'Start', 'Início', 'ホーム'],
    'newMapUnlocked': [
      'New map unlocked!',
      '¡Nuevo mapa desbloqueado!',
      'Nouvelle carte débloquée !',
      'Neue Karte freigeschaltet!',
      'Novo mapa desbloqueado!',
      '新マップ解放！',
    ],
    'levelUp': ['Level {n}!', '¡Nivel {n}!', 'Niveau {n} !', 'Level {n}!', 'Nível {n}!', 'レベル{n}！'],
    'xp': ['XP', 'XP', 'XP', 'EP', 'XP', 'XP'],
    'missionProgress': [
      'Mission progress!',
      '¡Progreso en misiones!',
      'Missions en progrès !',
      'Missionsfortschritt!',
      'Progresso nas missões!',
      'ミッション進行！',
    ],
    'dailyMissions': [
      'Daily Missions',
      'Misiones diarias',
      'Missions du jour',
      'Tagesmissionen',
      'Missões diárias',
      'デイリーミッション',
    ],
    'allDoneBonus': [
      'Finish all three for a bonus!',
      '¡Completa las tres para un bonus!',
      'Termine les trois pour un bonus !',
      'Schaffe alle drei für einen Bonus!',
      'Complete as três para um bônus!',
      '3つクリアでボーナス！',
    ],
    'swap': ['Swap', 'Cambiar', 'Changer', 'Tauschen', 'Trocar', '交換'],
    'done': ['Done!', '¡Hecho!', 'Fini !', 'Fertig!', 'Feito!', '達成！'],
    'newMissionsIn': [
      'New missions in {t}',
      'Nuevas misiones en {t}',
      'Nouvelles missions dans {t}',
      'Neue Missionen in {t}',
      'Novas missões em {t}',
      '新ミッションまで {t}',
    ],
    'm_eatPeople': [
      'Eat {n} people',
      'Come {n} personas',
      'Mange {n} passants',
      'Friss {n} Leute',
      'Coma {n} pessoas',
      '人を{n}人食べる',
    ],
    'm_eatProps': [
      'Eat {n} things',
      'Come {n} cosas',
      'Mange {n} objets',
      'Friss {n} Dinge',
      'Coma {n} coisas',
      'モノを{n}個食べる',
    ],
    'm_eatVehicles': [
      'Eat {n} vehicles',
      'Come {n} vehículos',
      'Mange {n} véhicules',
      'Friss {n} Fahrzeuge',
      'Coma {n} veículos',
      '乗り物を{n}台食べる',
    ],
    'm_eatBuildings': [
      'Eat {n} buildings',
      'Come {n} edificios',
      'Mange {n} bâtiments',
      'Friss {n} Gebäude',
      'Coma {n} prédios',
      '建物を{n}軒食べる',
    ],
    'm_eatRivals': [
      'Eat {n} monsters',
      'Come {n} monstruos',
      'Mange {n} monstres',
      'Friss {n} Monster',
      'Coma {n} monstros',
      'モンスターを{n}体食べる',
    ],
    'm_winRounds': [
      'Finish #1 ×{n}',
      'Termina #1 ×{n}',
      'Finis #1 ×{n}',
      'Werde #1 ×{n}',
      'Termine em #1 ×{n}',
      '1位を{n}回とる',
    ],
    'm_top3': [
      'Finish top 3 ×{n}',
      'Termina en el top 3 ×{n}',
      'Finis dans le top 3 ×{n}',
      'Werde Top 3 ×{n}',
      'Termine no top 3 ×{n}',
      '3位以内を{n}回とる',
    ],
    'm_playRounds': [
      'Play {n} rounds',
      'Juega {n} rondas',
      'Joue {n} manches',
      'Spiele {n} Runden',
      'Jogue {n} rodadas',
      '{n}ラウンド遊ぶ',
    ],
    'm_reachSize': [
      'Reach {n} m in one round',
      'Llega a {n} m en una ronda',
      'Atteins {n} m en une manche',
      'Erreiche {n} m in einer Runde',
      'Chegue a {n} m em uma rodada',
      '1ラウンドで{n}mになる',
    ],
    'luckyWheel': ['Lucky Wheel', 'Ruleta', 'Roue chanceuse', 'Glücksrad', 'Roleta', 'ラッキールーレット'],
    'spin': ['Spin!', '¡Girar!', 'Tourner !', 'Drehen!', 'Girar!', '回す！'],
    'spinAgain': ['Spin again', 'Girar otra vez', 'Encore un tour', 'Nochmal drehen', 'Girar de novo', 'もう一回'],
    'freeSpinIn': [
      'Free spin in {t}',
      'Giro gratis en {t}',
      'Tour gratuit dans {t}',
      'Gratis-Dreh in {t}',
      'Giro grátis em {t}',
      '無料まで {t}',
    ],
    'spinsLeft': [
      '{n} left today',
      'Quedan {n} hoy',
      'Encore {n} aujourd’hui',
      'Heute noch {n}',
      'Restam {n} hoje',
      '今日はあと{n}回',
    ],
    'youWon': ['You won', 'Ganaste', 'Tu gagnes', 'Gewonnen', 'Você ganhou', 'ゲット'],
    'removeAds': [
      'Remove ads',
      'Quitar anuncios',
      'Supprimer les pubs',
      'Werbung entfernen',
      'Remover anúncios',
      '広告を削除',
    ],
    'removeAdsDesc': [
      'No banners, no pop-up ads. Forever.',
      'Sin banners ni anuncios emergentes. Para siempre.',
      'Plus de bannières ni de pubs. Pour toujours.',
      'Keine Banner, keine Pop-up-Werbung. Für immer.',
      'Sem banners nem anúncios. Para sempre.',
      'バナーも全画面広告もずっとなし。',
    ],
    'adsRemoved': [
      'Ads removed',
      'Anuncios quitados',
      'Pubs supprimées',
      'Werbung entfernt',
      'Anúncios removidos',
      '広告削除済み',
    ],
    'coinPacks': ['Coin packs', 'Packs de monedas', 'Packs de pièces', 'Münzpakete', 'Pacotes de moedas', 'コインパック'],
    'storeUnavailable': [
      'The store is unavailable right now.',
      'La tienda no está disponible ahora.',
      "La boutique n'est pas disponible pour l'instant.",
      'Der Laden ist gerade nicht verfügbar.',
      'A loja não está disponível agora.',
      '現在ストアを利用できません。',
    ],
    'purchaseThanks': ['Thank you!', '¡Gracias!', 'Merci !', 'Danke!', 'Obrigado!', 'ありがとう！'],
    'purchaseFailed': [
      "The purchase didn't go through.",
      'La compra no se completó.',
      "L'achat n'a pas abouti.",
      'Der Kauf hat nicht geklappt.',
      'A compra não foi concluída.',
      '購入できませんでした。',
    ],
    'bestValue': ['Best value', 'Mejor oferta', 'Meilleure offre', 'Bestes Angebot', 'Melhor oferta', 'お得'],
    'coinsX': ['Coins ×{n}', 'Monedas ×{n}', 'Pièces ×{n}', 'Münzen ×{n}', 'Moedas ×{n}', 'コイン×{n}'],
    'rivals': ['{n} rivals', '{n} rivales', '{n} rivaux', '{n} Rivalen', '{n} rivais', 'ライバル{n}体'],
    'bestSize': ['Best {n} m', 'Récord {n} m', 'Record {n} m', 'Rekord {n} m', 'Recorde {n} m', 'ベスト {n}m'],
    'wins': ['{n} wins', '{n} victorias', '{n} victoires', '{n} Siege', '{n} vitórias', '{n}勝'],
    'map_town': ['Tiny Town', 'Pueblito', 'Petite Ville', 'Kleinstadt', 'Cidadezinha', 'ちいさな町'],
    'map_beach': ['Sunny Beach', 'Playa Soleada', 'Plage Ensoleillée', 'Sonnenstrand', 'Praia Ensolarada', 'サニービーチ'],
    'map_farm': ['Happy Farm', 'Granja Feliz', 'Ferme Joyeuse', 'Fröhlicher Hof', 'Fazenda Feliz', 'ハッピー牧場'],
    'map_snow': ['Snowy Village', 'Aldea Nevada', 'Village Enneigé', 'Schneedorf', 'Vila Nevada', '雪の村'],
    'map_city': ['Big City', 'Gran Ciudad', 'Grande Ville', 'Großstadt', 'Cidade Grande', '大都会'],
    'up_size': ['Start Size', 'Tamaño inicial', 'Taille de départ', 'Startgröße', 'Tamanho inicial', '初期サイズ'],
    'up_speed': ['Speed', 'Velocidad', 'Vitesse', 'Tempo', 'Velocidade', 'スピード'],
    'up_time': ['Round Time', 'Tiempo', 'Durée', 'Rundenzeit', 'Tempo', '制限時間'],
    'up_reach': ['Suction', 'Succión', 'Aspiration', 'Sog', 'Sucção', '吸い込み'],
    'up_coins': ['Coin Bonus', 'Bonus de monedas', 'Bonus de pièces', 'Münzbonus', 'Bônus de moedas', 'コインボーナス'],
    'updesc_size': [
      'Start every round bigger',
      'Empieza cada ronda más grande',
      'Commence chaque manche plus gros',
      'Starte jede Runde größer',
      'Comece cada rodada maior',
      '大きい状態でスタート',
    ],
    'updesc_speed': [
      'Move faster',
      'Muévete más rápido',
      'Déplace-toi plus vite',
      'Beweg dich schneller',
      'Mova-se mais rápido',
      '速く動ける',
    ],
    'updesc_time': [
      '+5 seconds per level',
      '+5 segundos por nivel',
      '+5 secondes par niveau',
      '+5 Sekunden pro Stufe',
      '+5 segundos por nível',
      'レベルごとに+5秒',
    ],
    'updesc_reach': [
      'Pull food in from farther away',
      'Atrae la comida desde más lejos',
      'Aspire la nourriture de plus loin',
      'Zieh Futter von weiter weg an',
      'Puxe comida de mais longe',
      '遠くの食べ物も吸い込む',
    ],
    'updesc_coins': [
      '+10% coins per level',
      '+10% de monedas por nivel',
      '+10 % de pièces par niveau',
      '+10 % Münzen pro Stufe',
      '+10% de moedas por nível',
      'レベルごとにコイン+10%',
    ],
  };
}

class _Delegate extends LocalizationsDelegate<Strings> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => Strings.languages.contains(locale.languageCode);

  @override
  Future<Strings> load(Locale locale) async => Strings(locale.languageCode);

  @override
  bool shouldReload(_Delegate old) => false;
}
