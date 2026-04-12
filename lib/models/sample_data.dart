// ─────────────────────────────────────────────────────────────
// sample_data.dart  –  Hardcoded mock data (mirrors the React mockup)
// Replace with real API calls once your backend is ready.
// ─────────────────────────────────────────────────────────────

import 'models.dart';

// ── Shared image URLs (Unsplash) ──────────────────────────────
const String imgBrunch =
    'https://images.unsplash.com/photo-1553321846-ad6616f5d1db?w=800&q=80';
const String imgCoffee =
    'https://images.unsplash.com/photo-1629991848910-2ab88d9cc52f?w=800&q=80';
const String imgIceCream =
    'https://images.unsplash.com/photo-1745914412106-dbdcf0a41377?w=800&q=80';
const String imgGroup =
    'https://images.unsplash.com/photo-1576267423445-b2e0074d68a4?w=800&q=80';

// ── Members ───────────────────────────────────────────────────
final List<Member> sampleMembers = [
  Member(id: '1', name: 'You', email: 'you@email.com', preferencesSet: true),
  Member(id: '2', name: 'Alex', email: 'alex@email.com', preferencesSet: true),
  Member(
    id: '3',
    name: 'Jordan',
    email: 'jordan@email.com',
    preferencesSet: false,
  ),
  Member(id: '4', name: 'Sam', email: 'sam@email.com', preferencesSet: true),
  Member(
    id: '5',
    name: 'Casey',
    email: 'casey@email.com',
    preferencesSet: false,
  ),
];

// ── Groups ────────────────────────────────────────────────────
final List<Group> sampleGroups = [
  Group(
    id: '1',
    name: 'College Squad 🎓',
    members: sampleMembers,
    nextHangout: 'March 8, 2026',
    imageUrl: imgGroup,
  ),
  Group(
    id: '2',
    name: 'Foodie Friends 🍕',
    members: sampleMembers.sublist(0, 3),
    nextHangout: 'March 12, 2026',
    imageUrl: imgBrunch,
  ),
];

// ── Default single-day itinerary (optional fallback) ──────────
final List<ItineraryStop> sampleItinerary = [
  ItineraryStop(
    id: '1',
    type: 'Brunch',
    name: 'The Corner Cafe',
    time: '11:00 AM',
    duration: '1.5 hrs',
    address: '123 Main St',
    distance: '0.3 mi',
    priceRange: r'$$',
    rating: 4.5,
    imageUrl: imgBrunch,
    matchScore: 95,
  ),
  ItineraryStop(
    id: '2',
    type: 'Coffee',
    name: 'Brew & Bean',
    time: '1:00 PM',
    duration: '45 min',
    address: '456 Oak Ave',
    distance: '0.5 mi',
    priceRange: r'$',
    rating: 4.7,
    imageUrl: imgCoffee,
    matchScore: 88,
  ),
  ItineraryStop(
    id: '3',
    type: 'Dessert',
    name: 'Sweet Treats Ice Cream',
    time: '3:30 PM',
    duration: '30 min',
    address: '789 Park Blvd',
    distance: '0.7 mi',
    priceRange: r'$',
    rating: 4.8,
    imageUrl: imgIceCream,
    matchScore: 92,
  ),
];

// ── Planner itineraries by date ───────────────────────────────
final Map<DateTime, List<ItineraryStop>> sampleItinerariesByDate = {
  DateTime(2026, 3, 8): [
    ItineraryStop(
      id: '1',
      type: 'Brunch',
      name: 'The Corner Cafe',
      time: '11:00 AM',
      duration: '1.5 hrs',
      address: '123 Main St',
      distance: '0.3 mi',
      priceRange: r'$$',
      rating: 4.5,
      imageUrl: imgBrunch,
      matchScore: 95,
    ),
    ItineraryStop(
      id: '2',
      type: 'Coffee',
      name: 'Brew & Bean',
      time: '1:00 PM',
      duration: '45 min',
      address: '456 Oak Ave',
      distance: '0.5 mi',
      priceRange: r'$',
      rating: 4.7,
      imageUrl: imgCoffee,
      matchScore: 88,
    ),
    ItineraryStop(
      id: '3',
      type: 'Dessert',
      name: 'Sweet Treats Ice Cream',
      time: '3:30 PM',
      duration: '30 min',
      address: '789 Park Blvd',
      distance: '0.7 mi',
      priceRange: r'$',
      rating: 4.8,
      imageUrl: imgIceCream,
      matchScore: 92,
    ),
  ],
  DateTime(2026, 3, 12): [
    ItineraryStop(
      id: '4',
      type: 'Lunch',
      name: 'Sunset Bistro',
      time: '12:30 PM',
      duration: '1 hr',
      address: '22 River Rd',
      distance: '0.4 mi',
      priceRange: r'$$',
      rating: 4.4,
      imageUrl: imgBrunch,
      matchScore: 91,
    ),
    ItineraryStop(
      id: '5',
      type: 'Coffee',
      name: 'Roast Lab',
      time: '2:00 PM',
      duration: '40 min',
      address: '89 Cedar St',
      distance: '0.2 mi',
      priceRange: r'$',
      rating: 4.6,
      imageUrl: imgCoffee,
      matchScore: 87,
    ),
  ],
  DateTime(2026, 3, 15): [
    ItineraryStop(
      id: '6',
      type: 'Dessert',
      name: 'Cloud Creamery',
      time: '4:00 PM',
      duration: '35 min',
      address: '10 Park Ave',
      distance: '0.6 mi',
      priceRange: r'$',
      rating: 4.9,
      imageUrl: imgIceCream,
      matchScore: 94,
    ),
  ],
};

// ── Bill items ────────────────────────────────────────────────
List<BillItem> get sampleBillItems => [
      BillItem(id: '1', name: 'Avocado Toast', price: 14.0, selectedBy: ['2']),
      BillItem(id: '2', name: 'Pancakes', price: 12.0, selectedBy: ['3']),
      BillItem(id: '3', name: 'Eggs Benedict', price: 16.0, selectedBy: ['4']),
      BillItem(id: '4', name: 'French Toast', price: 13.0, selectedBy: ['5']),
      BillItem(id: '5', name: 'Coffee (x2)', price: 8.0, selectedBy: ['2', '4']),
      BillItem(id: '6', name: 'Orange Juice', price: 5.0, selectedBy: ['3']),
      BillItem(id: '7', name: 'Latte', price: 5.5, selectedBy: ['5']),
    ];

// ── Photos ────────────────────────────────────────────────────
List<Photo> get samplePhotos => [
      Photo(id: '1', url: imgBrunch, uploadedBy: 'Alex', likes: 12, comments: 3),
      Photo(id: '2', url: imgCoffee, uploadedBy: 'Jordan', likes: 15, comments: 5),
      Photo(id: '3', url: imgIceCream, uploadedBy: 'Sam', likes: 18, comments: 7),
      Photo(id: '4', url: imgGroup, uploadedBy: 'Casey', likes: 24, comments: 9),
    ];

// ── Quests ────────────────────────────────────────────────────
List<Quest> get sampleQuests => [
      Quest(id: '1', description: 'Take a group selfie', completed: true),
      Quest(id: '2', description: 'Try something new on the menu', completed: true),
      Quest(id: '3', description: 'Find a street mural', completed: false),
    ];

// ── Scrapbook hangouts ────────────────────────────────────────
final List<Hangout> sampleHangouts = [
  Hangout(
    id: '1',
    date: 'March 8, 2026',
    title: 'Brunch & Dessert Adventure',
    group: 'College Squad',
    photoUrls: [imgBrunch, imgCoffee, imgIceCream, imgGroup],
    totalSpent: 42.50,
    places: 3,
    rating: 5,
    highlights: [
      'Amazing avocado toast at The Corner Cafe',
      'Best latte art we\'ve ever seen',
      'Got our quest stickers!',
    ],
    foodReview:
        'The Corner Cafe was incredible! The avocado toast was perfectly seasoned. '
        'Coffee was smooth and the barista was super friendly.',
  ),
  Hangout(
    id: '2',
    date: 'February 22, 2026',
    title: 'Pizza Night Downtown',
    group: 'College Squad',
    photoUrls: [imgGroup, imgBrunch],
    totalSpent: 35.00,
    places: 2,
    rating: 4,
    highlights: [
      'Wood-fired pizza was amazing',
      'Found a cool record store',
      'Late night ice cream run',
    ],
    foodReview:
        'Tony\'s Pizza never disappoints. The margherita had the perfect char on the crust.',
  ),
];

// ── Calendar events (NEW) ─────────────────────────────────────
final Map<DateTime, List<Map<String, String>>> sampleCalendarEvents = {
  DateTime(2026, 3, 8): [
    {'title': 'Brunch at The Corner Cafe', 'time': '11:00 AM', 'group': 'College Squad 🎓'},
    {'title': 'Coffee at Brew & Bean', 'time': '1:00 PM', 'group': 'College Squad 🎓'},
    {'title': 'Dessert at Sweet Treats Ice Cream', 'time': '3:30 PM', 'group': 'College Squad 🎓'},
  ],
  DateTime(2026, 3, 12): [
    {'title': 'Lunch at Sunset Bistro', 'time': '12:30 PM', 'group': 'Foodie Friends 🍕'},
    {'title': 'Coffee at Roast Lab', 'time': '2:00 PM', 'group': 'Foodie Friends 🍕'},
  ],
  DateTime(2026, 3, 15): [
    {'title': 'Dessert at Cloud Creamery', 'time': '4:00 PM', 'group': 'College Squad 🎓'},
  ],
};