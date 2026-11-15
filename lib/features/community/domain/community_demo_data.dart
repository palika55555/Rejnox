import 'package:flutter/material.dart';

/// Ukážkové údaje komunity. Server ich zatiaľ nemá, preto obrazovka
/// pri každej akcii hovorí, že funkcia pribudne čoskoro.
typedef CommunityPost = ({
  String author,
  String meta,
  String title,
  String body,
  IconData icon,
  String highlight,
  int likes,
  int comments,
});

typedef BuddyRequest = ({
  String name,
  String place,
  String when,
  String activity,
  String note,
});

typedef CommunityEvent = ({
  String title,
  String when,
  String place,
  int attendees,
  IconData icon,
});

typedef Challenge = ({
  String title,
  String description,
  int progress,
  int goal,
  String members,
  IconData icon,
});

typedef CommunityGroup = ({
  String name,
  String members,
  String description,
  IconData icon,
});

typedef LeaderboardEntry = ({String name, int workouts});

const demoPosts = <CommunityPost>[
  (
    author: 'Adam Král',
    meta: 'pred 2 h · Tréning',
    title: 'Ďalší krok vpred!',
    body:
        'Dnes nový osobný rekord na bench presse – 110 kg! '
        'Konzistencia sa vypláca.',
    icon: Icons.fitness_center_rounded,
    highlight: 'Bench press 110 kg',
    likes: 86,
    comments: 12,
  ),
  (
    author: 'Lucia Nováková',
    meta: 'pred 4 h · Strava',
    title: 'Jednoduchý a výživný obed',
    body: 'Malé návyky robia veľké výsledky. Čo máte dnes na obed?',
    icon: Icons.restaurant_rounded,
    highlight: 'Zdravý obed',
    likes: 42,
    comments: 8,
  ),
  (
    author: 'Tomáš Bela',
    meta: 'včera · Výzva',
    title: 'Splnených 30 dní!',
    body: 'Mesiac pravidelného pohybu za mnou. Kto ide do ďalšej výzvy?',
    icon: Icons.emoji_events_outlined,
    highlight: '30 dní v rade',
    likes: 129,
    comments: 19,
  ),
];

const demoBuddies = <BuddyRequest>[
  (
    name: 'Martin, 26',
    place: 'Žilina · FitUp Central',
    when: 'Dnes 17:30',
    activity: 'Hrudník, triceps',
    note: 'Hľadám parťáka na večerný tréning.',
  ),
  (
    name: 'Tamara, 24',
    place: 'Bratislava · GymBeam Gym',
    when: 'Zajtra 18:00',
    activity: 'Nohy',
    note: 'Niekto na tréning nôh?',
  ),
  (
    name: 'Peter, 29',
    place: 'Košice · Centrum',
    when: 'Sobota 9:00',
    activity: 'Beh 5 km',
    note: 'Pohodové tempo, vítaní aj začiatočníci.',
  ),
];

const demoEvents = <CommunityEvent>[
  (
    title: 'Spoločný tréning – Full Body',
    when: 'Sobota · 10:00',
    place: 'Bratislava · FitUp Central',
    attendees: 18,
    icon: Icons.groups_outlined,
  ),
  (
    title: 'Ranný beh – 5 km',
    when: 'Nedeľa · 8:00',
    place: 'Žilina · Sad SNP',
    attendees: 12,
    icon: Icons.directions_run_rounded,
  ),
  (
    title: 'Mobilita a strečing',
    when: 'Utorok · 18:30',
    place: 'Online',
    attendees: 26,
    icon: Icons.self_improvement_rounded,
  ),
];

const demoChallenges = <Challenge>[
  (
    title: '30 dní v pohybe',
    description: 'Odtrénuj aspoň 15 tréningov za 30 dní.',
    progress: 10,
    goal: 15,
    members: '1 248 účastníkov',
    icon: Icons.fitness_center_rounded,
  ),
  (
    title: '10 000 krokov denne',
    description: 'Dosiahni denný cieľ počas 7 dní.',
    progress: 5,
    goal: 7,
    members: '862 účastníkov',
    icon: Icons.directions_walk_rounded,
  ),
  (
    title: 'Plank výzva',
    description: 'Nazbieraj spolu 10 minút v planku.',
    progress: 6,
    goal: 10,
    members: '536 účastníkov',
    icon: Icons.timer_outlined,
  ),
];

const demoGroups = <CommunityGroup>[
  (
    name: 'Fitko Bratislava',
    members: '1 842 členov',
    description: 'Spoločné tréningy, udalosti a tipy.',
    icon: Icons.fitness_center_rounded,
  ),
  (
    name: 'Powerlifting SK',
    members: '436 členov',
    description: 'Sila, technika, súťaže a progres.',
    icon: Icons.sports_gymnastics_rounded,
  ),
  (
    name: 'Začiatočníci vo fitku',
    members: '1 203 členov',
    description: 'Podpora a motivácia pre každého.',
    icon: Icons.spa_outlined,
  ),
  (
    name: 'Bežci Slovensko',
    members: '2 897 členov',
    description: 'Bežecké výzvy a spoločné trasy.',
    icon: Icons.directions_run_rounded,
  ),
];

/// Zoradené od prvého miesta.
const demoLeaderboard = <LeaderboardEntry>[
  (name: 'Martin K.', workouts: 24),
  (name: 'Lucia N.', workouts: 20),
  (name: 'Tomáš B.', workouts: 18),
  (name: 'Petra M.', workouts: 17),
  (name: 'Adam H.', workouts: 16),
  (name: 'Veronika S.', workouts: 15),
];
