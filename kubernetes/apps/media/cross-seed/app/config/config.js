module.exports = {
  // ======== BASIC SETTINGS =========
  action: "inject",
  apiKey: "{{.CROSS_SEED_API_KEY}}",
  delay: 30,
  duplicateCategories: false,
  flatLinking: false,
  includeNonVideos: true,
  rssCadence: "10 minutes",
  includeSingleEpisodes: true,

  // ======== Blocklist =========
  blockList: ["category:snatches"],

  // ======== Container =========
  port: 80,
  outputDir: null,

  // ======== ID SEARCHING =========
  sonarr: [
    "http://sonarr.media.svc.cluster.local/?apikey={{ .SONARR_API_KEY }}",
  ],
  radarr: [
    "http://radarr.media.svc.cluster.local/?apikey={{ .RADARR_API_KEY }}",
  ],

  // ======== PARTIAL MATCHING (Requires Linking) =========
  matchMode: "partial",
  linkCategory: "cross-seed",
  linkDirs: ["/media/download/torrent/categories/cross-seed"],
  linkType: "hardlink",

  // ======== DATA BASED MATCHING (Requires Partial Matching) =========
  // Commented out, since you only need to ever run it once
  // After it successfully runs, comment it out.
  // maxDataDepth: 4,
  // dataDirs: [
  //    "/media/library/series",
  //    "/media/library/movies"
  // ],
  // excludeRecentSearch: "6 weeks",
  // excludeOlder: "12 weeks",
  // searchCadence: "2 weeks",

  // ======== PROWLARR =========
  torznab: [19, 28, 31].map(
    (i) =>
      `http://prowlarr.media.svc.cluster.local/$${i}/api?apikey={{ .PROWLARR_API_KEY }}`,
  ),

  // ======== TORRENT CLIENT =========
  qbittorrentUrl: "http://qbittorrent.media.svc.cluster.local",
  torrentDir: null,
  useClientTorrents: true,

  // ======== NOTIFICATIONS =========
  notificationWebhookUrls: ["{{ .NOTIFIARR_CROSS_SEED_WEBHOOK_URL }}"],
};
