// Peer model + mock RECENT_PEERS — direct port of godesk-shared.jsx data.
// Replaced by real RustDesk address-book bridge in Phase 2.3+.

enum PeerOS { windows, macos, linux }

enum PeerStatus { online, offline }

class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.os,
    required this.tag,
    required this.lastSeen,
    required this.status,
    this.fav = false,
  });

  final String id;
  final String name;
  final PeerOS os;
  final String tag;
  final String lastSeen;
  final PeerStatus status;
  final bool fav;

  bool get isOnline => status == PeerStatus.online;
}

const myId = '742 819 365';
const initialPassword = 'k7q-m4n';

const recentPeers = <Peer>[
  Peer(
    id: '184 220 591',
    name: "Maria's MacBook",
    os: PeerOS.macos,
    tag: 'Design',
    lastSeen: '2 min ago',
    status: PeerStatus.online,
    fav: true,
  ),
  Peer(
    id: '903 117 482',
    name: 'build-runner-03',
    os: PeerOS.linux,
    tag: 'DevOps',
    lastSeen: '12 min ago',
    status: PeerStatus.online,
  ),
  Peer(
    id: '551 008 226',
    name: 'Office Workstation',
    os: PeerOS.windows,
    tag: 'Personal',
    lastSeen: '1 hr ago',
    status: PeerStatus.online,
    fav: true,
  ),
  Peer(
    id: '412 766 990',
    name: 'Living Room PC',
    os: PeerOS.windows,
    tag: 'Home',
    lastSeen: 'Yesterday',
    status: PeerStatus.offline,
  ),
  Peer(
    id: '228 045 173',
    name: "Dad's iMac",
    os: PeerOS.macos,
    tag: 'Family',
    lastSeen: '2 days ago',
    status: PeerStatus.offline,
  ),
  Peer(
    id: '667 391 408',
    name: 'kiosk-lobby',
    os: PeerOS.linux,
    tag: 'Kiosks',
    lastSeen: '3 days ago',
    status: PeerStatus.online,
  ),
];
