class LiveMatchesResponse {
  bool? success;
  int? totalCount;
  int? liveCount;
  int? upcomingCount;
  int? completedCount;
  List<CricketMatch>? matches;

  LiveMatchesResponse({
    this.success,
    this.totalCount,
    this.liveCount,
    this.upcomingCount,
    this.completedCount,
    this.matches,
  });

  LiveMatchesResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    totalCount = json['totalCount'] ?? json['count'];
    final stats = json['stats'];
    if (stats is Map) {
      liveCount = stats['live'];
      upcomingCount = stats['upcoming'];
      completedCount = stats['completed'];
      totalCount = stats['total'] ?? totalCount;
    }
    liveCount ??= json['liveCount'];
    upcomingCount ??= json['upcomingCount'];
    completedCount ??= json['completedCount'];

    if (json['matches'] != null) {
      matches = <CricketMatch>[];
      json['matches'].forEach((v) {
        matches!.add(CricketMatch.fromJson(Map<String, dynamic>.from(v)));
      });
    }
  }
}

class CricketMatch {
  String? id;
  String? title;
  String? format;
  String? status;
  bool? isLive;
  String? tournament;
  String? venue;
  String? banner;
  String? streamThumbnailUrl;
  TeamInfo? team1;
  TeamInfo? team2;
  String? currentRunRate;
  String? requiredRunRate;
  dynamic target;
  String? latestTicker;
  int? viewerCount;
  String? streamUrl;
  String? backupStreamUrl;
  String? streamType;
  String? toss;
  LiveCrease? liveCrease;
  SquadsInfo? squads;
  ScorecardModel? scorecard;
  List<CommentaryItem>? commentary;

  CricketMatch({
    this.id,
    this.title,
    this.format,
    this.status,
    this.isLive,
    this.tournament,
    this.venue,
    this.banner,
    this.streamThumbnailUrl,
    this.team1,
    this.team2,
    this.currentRunRate,
    this.requiredRunRate,
    this.target,
    this.latestTicker,
    this.viewerCount,
    this.streamUrl,
    this.backupStreamUrl,
    this.streamType,
    this.toss,
    this.liveCrease,
    this.squads,
    this.scorecard,
    this.commentary,
  });

  CricketMatch.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['matchId'] ?? json['id'];
    title = json['title'];
    format = json['format'] ?? json['matchFormat'];
    status = json['status'];
    isLive = json['isLive'];
    tournament = json['tournament'];
    venue = json['venue'];
    banner = json['banner'] ?? json['streamThumbnailUrl'] ?? json['streamThumbnail'] ?? json['bannerUrl'];
    streamThumbnailUrl = json['streamThumbnailUrl'] ?? json['banner'] ?? json['streamThumbnail'] ?? json['bannerUrl'];

    final t1 = json['team1'] ?? json['teamA'];
    final t2 = json['team2'] ?? json['teamB'];
    team1 = t1 != null ? TeamInfo.fromJson(Map<String, dynamic>.from(t1)) : null;
    team2 = t2 != null ? TeamInfo.fromJson(Map<String, dynamic>.from(t2)) : null;

    currentRunRate = (json['currentRunRate'] ?? json['CRR'] ?? json['crr'])?.toString();
    requiredRunRate = (json['requiredRunRate'] ?? json['RRR'] ?? json['rrr'])?.toString();
    target = json['target'];
    latestTicker = json['latestTicker'] ?? json['currentStatusText'];
    viewerCount = json['viewerCount'] ?? json['viewersCount'];
    streamUrl = json['streamUrl'];
    backupStreamUrl = json['backupStreamUrl'];
    streamType = json['streamType'];
    toss = json['toss'];

    liveCrease = json['liveCrease'] != null
        ? LiveCrease.fromJson(Map<String, dynamic>.from(json['liveCrease']))
        : LiveCrease.fromLiveActivityJson(json);
    squads = json['squads'] != null
        ? SquadsInfo.fromJson(Map<String, dynamic>.from(json['squads']))
        : SquadsInfo.fromSquadsApiJson(json);
    scorecard = json['scorecard'] != null
        ? ScorecardModel.fromJson(Map<String, dynamic>.from(json['scorecard']))
        : ScorecardModel.fromScorecardApiJson(json);

    if (json['commentary'] != null) {
      commentary = <CommentaryItem>[];
      json['commentary'].forEach((v) {
        commentary!.add(CommentaryItem.fromJson(Map<String, dynamic>.from(v)));
      });
    }
  }
}

class TeamInfo {
  String? name;
  String? shortName;
  String? logo;
  String? score;
  String? overs;
  int? runs;
  int? wickets;
  bool? isBatting;
  List<SquadMember>? players;

  TeamInfo({
    this.name,
    this.shortName,
    this.logo,
    this.score,
    this.overs,
    this.runs,
    this.wickets,
    this.isBatting,
    this.players,
  });

  TeamInfo.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    shortName = json['shortName'];
    logo = json['logo'] ?? json['flagUrl'];
    score = json['score']?.toString();
    overs = json['overs']?.toString();
    runs = json['runs'];
    wickets = json['wickets'];
    isBatting = json['isBatting'];
    if (json['players'] != null) {
      players = <SquadMember>[];
      json['players'].forEach((v) {
        players!.add(SquadMember.fromJson(Map<String, dynamic>.from(v)));
      });
    }
  }
}

class LiveCrease {
  BatsmanStat? striker;
  BatsmanStat? nonStriker;
  BowlerStat? currentBowler;
  List<String>? recentBalls;
  String? overStatusText;
  String? currentRunRate;

  LiveCrease({
    this.striker,
    this.nonStriker,
    this.currentBowler,
    this.recentBalls,
    this.overStatusText,
    this.currentRunRate,
  });

  LiveCrease.fromJson(Map<String, dynamic> json) {
    striker = json['striker'] != null ? BatsmanStat.fromJson(Map<String, dynamic>.from(json['striker'])) : null;
    nonStriker = json['nonStriker'] != null ? BatsmanStat.fromJson(Map<String, dynamic>.from(json['nonStriker'])) : null;

    final b = json['currentBowler'] ?? json['bowler'];
    currentBowler = b != null ? BowlerStat.fromJson(Map<String, dynamic>.from(b)) : null;

    if (json['recentBalls'] != null) {
      recentBalls = List<String>.from(json['recentBalls'].map((e) => e.toString()));
    }
    overStatusText = json['overStatusText'] ?? json['currentStatusText'];
    currentRunRate = (json['currentRunRate'] ?? json['CRR'] ?? json['crr'])?.toString();
  }

  LiveCrease.fromLiveActivityJson(Map<String, dynamic> json) {
    striker = json['striker'] != null ? BatsmanStat.fromJson(Map<String, dynamic>.from(json['striker'])) : null;
    nonStriker = json['nonStriker'] != null ? BatsmanStat.fromJson(Map<String, dynamic>.from(json['nonStriker'])) : null;

    final b = json['currentBowler'] ?? json['bowler'];
    currentBowler = b != null ? BowlerStat.fromJson(Map<String, dynamic>.from(b)) : null;

    if (json['recentBalls'] != null) {
      recentBalls = List<String>.from(json['recentBalls'].map((e) => e.toString()));
    }
    overStatusText = json['currentStatusText'];
    currentRunRate = json['crr']?.toString();
  }
}

class BatsmanStat {
  String? name;
  int? runs;
  int? balls;
  int? fours;
  int? sixes;
  String? strikeRate;
  bool? isOnStrike;

  BatsmanStat({
    this.name,
    this.runs,
    this.balls,
    this.fours,
    this.sixes,
    this.strikeRate,
    this.isOnStrike,
  });

  BatsmanStat.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? json['playerName'];
    runs = json['runs'];
    balls = json['balls'];
    fours = json['fours'] ?? json['4s'];
    sixes = json['sixes'] ?? json['6s'];
    strikeRate = (json['strikeRate'] ?? json['SR'])?.toString();
    isOnStrike = json['isOnStrike'];
  }
}

class BowlerStat {
  String? name;
  String? overs;
  int? maidens;
  int? runs;
  int? wickets;
  String? economy;

  BowlerStat({
    this.name,
    this.overs,
    this.maidens,
    this.runs,
    this.wickets,
    this.economy,
  });

  BowlerStat.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? json['bowlerName'];
    overs = json['overs']?.toString();
    maidens = json['maidens'];
    runs = json['runs'] ?? json['runsConceded'];
    wickets = json['wickets'];
    economy = json['economy']?.toString();
  }
}

class SquadsInfo {
  String? team1Name;
  String? team2Name;
  List<SquadMember>? team1Squad;
  List<SquadMember>? team2Squad;

  SquadsInfo({this.team1Name, this.team2Name, this.team1Squad, this.team2Squad});

  SquadsInfo.fromJson(Map<String, dynamic> json) {
    final t1 = json['team1'] ?? json['teamA'];
    if (t1 != null) {
      team1Name = t1['name'];
      if (t1['players'] != null) {
        team1Squad = (t1['players'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
      }
    }
    final t2 = json['team2'] ?? json['teamB'];
    if (t2 != null) {
      team2Name = t2['name'];
      if (t2['players'] != null) {
        team2Squad = (t2['players'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
      }
    }

    if (json['team1Squad'] != null) {
      team1Squad = (json['team1Squad'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
    }
    if (json['team2Squad'] != null) {
      team2Squad = (json['team2Squad'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
    }
  }

  SquadsInfo.fromSquadsApiJson(Map<String, dynamic> json) {
    final t1 = json['team1'] ?? json['teamA'];
    if (t1 != null) {
      team1Name = t1['name'];
      if (t1['players'] != null) {
        team1Squad = (t1['players'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
      }
    }
    final t2 = json['team2'] ?? json['teamB'];
    if (t2 != null) {
      team2Name = t2['name'];
      if (t2['players'] != null) {
        team2Squad = (t2['players'] as List).map((v) => SquadMember.fromJson(Map<String, dynamic>.from(v))).toList();
      }
    }
  }
}

class SquadMember {
  String? name;
  String? role;
  bool? isCaptain;
  bool? isWicketKeeper;

  SquadMember({this.name, this.role, this.isCaptain, this.isWicketKeeper});

  SquadMember.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    role = json['role'];
    isCaptain = json['isCaptain'];
    isWicketKeeper = json['isWicketKeeper'];
  }
}

class ScorecardModel {
  InningsScorecard? innings1;
  InningsScorecard? innings2;

  ScorecardModel({this.innings1, this.innings2});

  ScorecardModel.fromJson(Map<String, dynamic> json) {
    innings1 = json['innings1'] != null ? InningsScorecard.fromJson(Map<String, dynamic>.from(json['innings1'])) : null;
    innings2 = json['innings2'] != null ? InningsScorecard.fromJson(Map<String, dynamic>.from(json['innings2'])) : null;
  }

  ScorecardModel.fromScorecardApiJson(Map<String, dynamic> json) {
    innings1 = json['innings1'] != null ? InningsScorecard.fromJson(Map<String, dynamic>.from(json['innings1'])) : null;
    innings2 = json['innings2'] != null ? InningsScorecard.fromJson(Map<String, dynamic>.from(json['innings2'])) : null;
  }
}

class InningsScorecard {
  String? teamName;
  String? totalScore;
  String? overs;
  List<BattingEntry>? batting;
  List<BowlingEntry>? bowling;
  String? extras;
  List<FallOfWicketEntry>? fallOfWickets;

  InningsScorecard({
    this.teamName,
    this.totalScore,
    this.overs,
    this.batting,
    this.bowling,
    this.extras,
    this.fallOfWickets,
  });

  InningsScorecard.fromJson(Map<String, dynamic> json) {
    teamName = json['teamName'];
    if (teamName == null || teamName!.isEmpty) {
      teamName = json['name'];
    }
    totalScore = (json['totalScore'] ?? json['score'])?.toString();
    overs = json['overs']?.toString();

    if (json['extras'] is Map) {
      final ext = json['extras'] as Map;
      extras = 'Total: ${ext['total'] ?? 0} (b ${ext['byes'] ?? 0}, lb ${ext['legByes'] ?? 0}, w ${ext['wides'] ?? 0}, nb ${ext['noBalls'] ?? 0})';
    } else {
      extras = json['extras']?.toString();
    }

    final batList = json['batting'] ?? json['batsmen'];
    if (batList != null && batList is List) {
      batting = batList.map((v) => BattingEntry.fromJson(Map<String, dynamic>.from(v))).toList();
    }

    final bowlList = json['bowling'] ?? json['bowlers'];
    if (bowlList != null && bowlList is List) {
      bowling = bowlList.map((v) => BowlingEntry.fromJson(Map<String, dynamic>.from(v))).toList();
    }

    final fowList = json['fallOfWickets'] ?? json['fow'];
    if (fowList != null && fowList is List) {
      fallOfWickets = fowList.map((v) => FallOfWicketEntry.fromJson(Map<String, dynamic>.from(v))).toList();
    }
  }
}

class BattingEntry {
  String? batsman;
  String? dismissal;
  int? runs;
  int? balls;
  int? fours;
  int? sixes;
  String? strikeRate;
  bool? isNotOut;

  BattingEntry({
    this.batsman,
    this.dismissal,
    this.runs,
    this.balls,
    this.fours,
    this.sixes,
    this.strikeRate,
    this.isNotOut,
  });

  BattingEntry.fromJson(Map<String, dynamic> json) {
    batsman = json['batsman'] ?? json['playerName'] ?? json['name'];
    dismissal = json['dismissal'] ?? json['dismissalText'];
    runs = json['runs'];
    balls = json['balls'];
    fours = json['fours'] ?? json['4s'];
    sixes = json['sixes'] ?? json['6s'];
    strikeRate = (json['strikeRate'] ?? json['SR'])?.toString();
    isNotOut = json['isNotOut'] ?? !(json['isOut'] ?? false);
  }
}

class BowlingEntry {
  String? bowler;
  String? overs;
  int? maidens;
  int? runs;
  int? wickets;
  String? economy;

  BowlingEntry({
    this.bowler,
    this.overs,
    this.maidens,
    this.runs,
    this.wickets,
    this.economy,
  });

  BowlingEntry.fromJson(Map<String, dynamic> json) {
    bowler = json['bowler'] ?? json['bowlerName'] ?? json['name'];
    overs = json['overs']?.toString();
    maidens = json['maidens'];
    runs = json['runs'] ?? json['runsConceded'];
    wickets = json['wickets'];
    economy = json['economy']?.toString();
  }
}

class FallOfWicketEntry {
  String? wicketNumber;
  String? score;
  String? player;
  String? over;

  FallOfWicketEntry({this.wicketNumber, this.score, this.player, this.over});

  FallOfWicketEntry.fromJson(Map<String, dynamic> json) {
    wicketNumber = json['wicketNumber']?.toString();
    score = json['score']?.toString();
    player = json['player'] ?? json['playerName'];
    over = json['over']?.toString();
  }
}

class CommentaryItem {
  String? overBall;
  String? text;
  int? runs;
  bool? isBoundary;
  bool? isSix;
  bool? isWicket;

  CommentaryItem({
    this.overBall,
    this.text,
    this.runs,
    this.isBoundary,
    this.isSix,
    this.isWicket,
  });

  CommentaryItem.fromJson(Map<String, dynamic> json) {
    final ov = json['over']?.toString();
    final bl = json['ball']?.toString();
    if (ov != null && bl != null) {
      overBall = '$ov.$bl';
    } else {
      overBall = json['overBall'] ?? json['over.ball'];
    }
    text = json['text'];
    runs = json['runs'];
    isBoundary = json['isBoundary'];
    isSix = json['isSix'] ?? json['isBoundary'];
    isWicket = json['isWicket'];
  }
}
