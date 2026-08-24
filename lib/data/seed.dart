import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';

/// Mock content mirroring the web app's seed data
/// (`app/data/seed.js` plus representative API-backed entities). Kept in one
/// place so screens read from a single source, the way the web store does.

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    required this.color,
    this.online = false,
    this.lastActive = 'Active recently',
  });

  final String id;
  final String name;
  final String initials;
  final String role;
  final Color color;
  final bool online;
  final String lastActive;
}

class Reaction {
  const Reaction(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// Post kinds mirror the web PostCard branches.
enum PostKind { text, announcement, kudos, poll, photo }

class PollOption {
  PollOption(this.label, this.votes);
  final String label;
  int votes;
}

class Comment {
  Comment({
    required this.author,
    required this.text,
    this.likes = 0,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  final Person author;
  final String text;
  int likes;

  /// Threaded replies to this comment.
  final List<Comment> replies;

  /// Whether the current user has liked this comment.
  bool liked = false;
}

class Post {
  Post({
    required this.id,
    required this.author,
    required this.time,
    required this.kind,
    this.text = '',
    this.title = '',
    this.details = const [],
    this.note = '',
    this.signoff = '',
    this.kudosTo = '',
    this.pollOptions = const [],
    this.pinned = false,
    List<Comment>? comments,
    this.likeCount = 0,
    this.shareCount = 0,
  }) : comments = comments ?? [];

  final String id;
  final Person author;
  final String time;
  final PostKind kind;
  final String text;
  final String title;
  final List<MapEntry<String, String>> details;
  final String note;
  final String signoff;
  final String kudosTo;
  final List<PollOption> pollOptions;
  final bool pinned;
  final List<Comment> comments;
  int likeCount;
  int shareCount;

  bool liked = false;
  bool saved = false;
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.day,
    required this.mon,
    required this.time,
    required this.location,
    required this.desc,
    required this.attendees,
    this.interested = 0,
    this.featured = false,
  });

  final String id;
  final String title;
  final String date;
  final String day;
  final String mon;
  final String time;
  final String location;
  final String desc;
  final int attendees;
  final int interested;
  final bool featured;
}

class Group {
  const Group({
    required this.name,
    required this.members,
    required this.color,
    required this.desc,
  });
  final String name;
  final int members;
  final Color color;
  final String desc;
}

class Listing {
  const Listing({
    required this.title,
    required this.price,
    required this.category,
    required this.seller,
    required this.color,
    this.free = false,
  });
  final String title;
  final String price;
  final String category;
  final String seller;
  final Color color;
  final bool free;
}

class Story {
  const Story(this.name, this.initials, this.color);
  final String name;
  final String initials;
  final Color color;
}

// ---- Reactions (web REACTIONS) ----
const reactions = <Reaction>[
  Reaction('like', 'Like', Icons.thumb_up_alt_rounded, ArdentColors.accent),
  Reaction('celebrate', 'Celebrate', Icons.celebration_rounded, Color(0xFFC77700)),
  Reaction('support', 'Support', Icons.favorite_rounded, ArdentColors.crimson500),
  Reaction('insightful', 'Insightful', Icons.lightbulb_rounded, ArdentColors.navy600),
];

class Seed {
  Seed._();

  static const currentUser = Person(
    id: 'me',
    name: 'Ramon Napa',
    initials: 'RN',
    role: 'Community Member',
    color: ArdentColors.navy700,
    online: true,
    lastActive: 'Active now',
  );

  static const people = <Person>[
    Person(id: 'p1', name: 'Dana Okafor', initials: 'DO', role: 'HR Business Partner', color: ArdentColors.navy700, online: true, lastActive: 'Active now'),
    Person(id: 'p2', name: 'Mika Reyes', initials: 'MR', role: 'Product Designer', color: ArdentColors.navy500, online: true, lastActive: 'Active now'),
    Person(id: 'p3', name: 'Priya Nandakumar', initials: 'PN', role: 'Engineering Lead', color: ArdentColors.crimson500, online: false, lastActive: 'Active 20m ago'),
    Person(id: 'p4', name: 'Jordan Villanueva', initials: 'JV', role: 'Executive', color: ArdentColors.navy800, online: false, lastActive: 'Active 1h ago'),
    Person(id: 'p5', name: 'Sam Tuazon', initials: 'ST', role: 'Marketing', color: ArdentColors.navy600, online: true, lastActive: 'Active now'),
    Person(id: 'p6', name: 'Elena Bautista', initials: 'EB', role: 'Finance', color: Color(0xFF8E2237), online: false, lastActive: 'Active 3h ago'),
  ];

  static const stories = <Story>[
    Story('Dana Okafor', 'DO', ArdentColors.navy700),
    Story('Mika Reyes', 'MR', ArdentColors.navy500),
    Story('Priya Nandakumar', 'PN', ArdentColors.crimson500),
    Story('Jordan Villanueva', 'JV', ArdentColors.navy800),
    Story('Sam Tuazon', 'ST', ArdentColors.navy600),
    Story('Elena Bautista', 'EB', Color(0xFF8E2237)),
  ];

  static const events = <EventItem>[
    EventItem(id: 'e1', title: "Ardent's First Houses' Sportsfest 2026", date: 'Fri, Jul 17, 2026', day: '17', mon: 'JUL', time: '11:00 AM – 4:00 PM', location: "Toby's Arena, Pasig City", desc: 'Badminton, volleyball, and basketball — come show your House spirit and support your team.', attendees: 118, interested: 34, featured: true),
    EventItem(id: 'e2', title: 'All-Hands Town Hall', date: 'Wed, Aug 5, 2026', day: '05', mon: 'AUG', time: '3:00 – 4:00 PM', location: 'Main Auditorium + Zoom', desc: 'Q3 roadmap, team shoutouts, and open Q&A.', attendees: 212, interested: 45),
    EventItem(id: 'e3', title: 'New Hire Orientation', date: 'Mon, Jul 27, 2026', day: '27', mon: 'JUL', time: '9:00 – 11:00 AM', location: 'HR Training Room', desc: 'Welcome session for July new joiners.', attendees: 14, interested: 6),
    EventItem(id: 'e4', title: 'Design Crit Friday', date: 'Fri, Jul 24, 2026', day: '24', mon: 'JUL', time: '2:00 – 3:00 PM', location: 'Design Studio', desc: 'Bring work in progress for group feedback.', attendees: 22, interested: 11),
  ];

  static const groups = <Group>[
    Group(name: 'Engineering Guild', members: 84, color: ArdentColors.navy700, desc: 'Backend, frontend, and platform folks sharing what they build.'),
    Group(name: 'Design Community', members: 41, color: ArdentColors.crimson500, desc: 'Critique, resources, and design-system talk.'),
    Group(name: 'People & Culture', members: 63, color: ArdentColors.navy500, desc: 'Wellbeing, events, and everything HR.'),
    Group(name: 'Sportsfest 2026', members: 118, color: ArdentColors.accent, desc: 'House spirit HQ — schedules, teams, and results.'),
    Group(name: 'Book Club', members: 27, color: ArdentColors.navy600, desc: 'One book a month, zero pressure.'),
  ];

  static const marketCategories = ['All', 'Furniture', 'Electronics', 'Vehicles', 'Free'];

  static const listings = <Listing>[
    Listing(title: 'Herman Miller Aeron Chair', price: '₱12,500', category: 'Furniture', seller: 'Sam Tuazon', color: ArdentColors.navy600),
    Listing(title: 'iPad Air (5th gen, 64GB)', price: '₱21,000', category: 'Electronics', seller: 'Priya Nandakumar', color: ArdentColors.crimson500),
    Listing(title: 'Mountain Bike — 27.5"', price: '₱8,900', category: 'Vehicles', seller: 'Jordan Villanueva', color: ArdentColors.navy700),
    Listing(title: 'Moving out — free plants 🌿', price: 'Free', category: 'Free', seller: 'Elena Bautista', color: ArdentColors.statusResolved, free: true),
    Listing(title: 'Mechanical Keyboard (TKL)', price: '₱3,200', category: 'Electronics', seller: 'Mika Reyes', color: ArdentColors.navy500),
    Listing(title: 'Standing Desk Frame', price: '₱6,500', category: 'Furniture', seller: 'Dana Okafor', color: ArdentColors.navy800),
  ];

  static List<Post> buildPosts() {
    final p = people;
    return [
      Post(
        id: 'post1',
        author: p[0],
        time: '2h ago',
        kind: PostKind.announcement,
        pinned: true,
        title: "Ardent's First Houses' Sportsfest 2026",
        text: "It's official — our very first company-wide Sportsfest is happening this July! Rally your House and get ready.",
        details: const [
          MapEntry('When', 'Fri, Jul 17, 2026 · 11:00 AM'),
          MapEntry('Where', "Toby's Arena, Pasig City"),
          MapEntry('Events', 'Badminton, Volleyball, Basketball'),
        ],
        note: 'Sign-ups open next week through your House captains.',
        signoff: '— People & Culture',
        likeCount: 96,
        shareCount: 12,
        comments: [
          Comment(author: p[4], text: 'Team Crimson, assemble! 🔥', likes: 8),
          Comment(author: p[2], text: 'Finally! Been waiting for this.', likes: 4),
        ],
      ),
      Post(
        id: 'post2',
        author: p[3],
        time: '4h ago',
        kind: PostKind.kudos,
        kudosTo: 'Priya Nandakumar',
        text: 'For shipping the new onboarding flow two days early and mentoring three new hires while doing it. Incredible work.',
        likeCount: 54,
        shareCount: 3,
        comments: [
          Comment(author: p[1], text: 'So well deserved 👏', likes: 6),
        ],
      ),
      Post(
        id: 'post3',
        author: p[1],
        time: '6h ago',
        kind: PostKind.poll,
        text: 'For the next team lunch, where should we go?',
        pollOptions: [
          PollOption('Ramen place downtown', 12),
          PollOption('That new Filipino BBQ spot', 19),
          PollOption('Pizza in the office', 7),
        ],
        likeCount: 10,
        shareCount: 0,
        comments: [],
      ),
      Post(
        id: 'post4',
        author: p[5],
        time: 'Yesterday',
        kind: PostKind.text,
        text: 'Reminder: Q3 benefits enrollment closes Friday. Ping me if you need help with the forms — happy to walk anyone through it. 💙',
        likeCount: 23,
        shareCount: 5,
        comments: [
          Comment(author: p[0], text: 'Thanks for the heads up!', likes: 2),
        ],
      ),
    ];
  }
}
