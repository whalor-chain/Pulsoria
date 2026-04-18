import SwiftUI

struct AppearanceView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var showSymbolPicker = false

    var body: some View {
        List {
            themeSection
            appIconSection
            sliderIconSection
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle(Loc.appearance)
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerSheet()
        }
    }

    // MARK: - Accent Color

    private var themeSection: some View {
        Section(Loc.accentColor) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(AppTheme.allCases) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.currentTheme = t
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [t.accent, t.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)

                                if theme.currentTheme == t {
                                    Image(systemName: "checkmark")
                                        .font(.body.bold())
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(t.rawValue)
                                .font(.custom(Loc.fontMedium, size: 11))
                                .foregroundStyle(
                                    theme.currentTheme == t
                                        ? theme.currentTheme.accent
                                        : .secondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            // Preview
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent.opacity(0.5),
                                theme.currentTheme.secondary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Loc.previewTrack)
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(theme.currentTheme.accent)
                    Text(Loc.artistName)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.currentTheme.accent)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - App Icon

    private var appIconSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(Loc.appIcon)
                } icon: {
                    Image(systemName: "app.fill")
                        .foregroundStyle(theme.currentTheme.accent)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(AppIconVariant.allCases) { variant in
                            Button {
                                withAnimation(.smooth(duration: 0.3)) {
                                    setAppIcon(variant)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(uiImage: variant.preview)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(
                                                    currentIconVariant == variant
                                                        ? theme.currentTheme.accent
                                                        : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(
                                            color: currentIconVariant == variant
                                                ? theme.currentTheme.accent.opacity(0.4)
                                                : .clear,
                                            radius: 8
                                        )

                                    Text(variant.displayName)
                                        .font(.custom(Loc.fontMedium, size: 11))
                                        .foregroundStyle(
                                            currentIconVariant == variant
                                                ? theme.currentTheme.accent
                                                : .secondary
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: currentIconVariant)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var currentIconVariant: AppIconVariant {
        if let name = UIApplication.shared.alternateIconName,
           let variant = AppIconVariant.allCases.first(where: { $0.iconName == name }) {
            return variant
        }
        return .default_
    }

    private func setAppIcon(_ variant: AppIconVariant) {
        let name = variant == .default_ ? nil : variant.iconName
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
    }

    // MARK: - Slider Icon

    private var sliderIconSection: some View {
        Section {
            Button {
                showSymbolPicker = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.currentTheme.accent.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: theme.activeSliderSymbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.customSliderSymbol.isEmpty ? "circle.fill" : theme.customSliderSymbol)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text(Loc.sliderIconHint)
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.vertical, 4)

            if theme.sliderIcon == .custom && !theme.customSliderSymbol.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        theme.sliderIcon = .defaultCircle
                        theme.customSliderSymbol = ""
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(theme.language == .russian ? "Сбросить по умолчанию" : "Reset to default")
                    }
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(theme.currentTheme.accent)
                }
            }
        } header: {
            Text(Loc.sliderIcon)
        }
    }
}

// MARK: - SF Symbol Picker Sheet

struct SFSymbolPickerSheet: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory = 0
    @Namespace private var categoryNamespace

    private static let categoryData: [(icon: String, nameRU: String, nameEN: String, symbols: [String])] = [
        ("clock", "Последние", "Recent", []),
        ("star.fill", "Популярные", "Popular", [
            "circle.fill", "circle", "square.fill", "triangle.fill",
            "heart.fill", "heart", "heart.circle.fill", "heart.slash.fill",
            "star.fill", "star", "star.circle.fill", "star.square.fill",
            "flame.fill", "flame", "flame.circle.fill",
            "bolt.fill", "bolt", "bolt.circle.fill", "bolt.heart.fill",
            "moon.fill", "moon", "sun.max.fill", "sun.min.fill",
            "sparkles", "sparkle", "wand.and.stars", "wand.and.rays",
            "crown.fill", "crown", "diamond.fill", "diamond",
            "drop.fill", "drop", "leaf.fill", "snowflake",
            "eye.fill", "eye", "eye.slash.fill",
            "hand.raised.fill", "bell.fill", "bell", "bell.badge.fill",
            "tag.fill", "tag", "bookmark.fill", "bookmark",
            "pin.fill", "pin", "mappin", "mappin.circle.fill",
            "flag.fill", "flag", "flag.checkered",
            "location.fill", "scope", "target",
            "rosette", "seal.fill", "checkmark.seal.fill",
            "mustache.fill", "brain.head.profile", "brain",
            "cross.fill", "plus.circle.fill", "minus.circle.fill",
            "checkmark.circle.fill", "xmark.circle.fill"
        ]),
        ("car.fill", "Транспорт", "Transport", [
            "car.fill", "car", "car.side.fill", "car.side",
            "bolt.car.fill", "bolt.car", "car.rear.fill",
            "truck.box.fill", "truck.box", "truck.box.badge.clock.fill",
            "bus.fill", "bus", "bus.doubledecker.fill",
            "tram.fill", "tram", "cablecar.fill", "cablecar",
            "ferry.fill", "ferry", "sailboat.fill", "sailboat",
            "airplane", "airplane.departure", "airplane.arrival", "airplane.circle.fill",
            "bicycle", "bicycle.circle.fill",
            "skateboard.fill", "skateboard", "scooter",
            "surfboard.fill", "surfboard",
            "fuelpump.fill", "fuelpump",
            "steeringwheel.fill", "steeringwheel",
            "engine.combustion.fill", "engine.combustion",
            "train.side.front.car", "train.side.middle.car", "train.side.rear.car",
            "lightrail.fill", "lightrail",
            "rocket.fill", "rocket",
            "helicopter.fill", "helicopter",
            "box.truck.fill", "box.truck",
            "cart.fill", "cart"
        ]),
        ("pawprint.fill", "Животные", "Animals", [
            "pawprint.fill", "pawprint", "pawprint.circle.fill",
            "cat.fill", "cat", "cat.circle.fill",
            "dog.fill", "dog", "dog.circle.fill",
            "hare.fill", "hare",
            "tortoise.fill", "tortoise",
            "bird.fill", "bird", "bird.circle.fill",
            "fish.fill", "fish", "fish.circle.fill",
            "lizard.fill", "lizard",
            "ant.fill", "ant", "ant.circle.fill",
            "ladybug.fill", "ladybug",
            "teddybear.fill", "teddybear",
            "leaf.fill", "leaf", "leaf.circle.fill",
            "tree.fill", "tree",
            "fossil.shell.fill", "fossil.shell",
            "microbe.fill", "microbe", "microbe.circle.fill",
            "allergens.fill", "allergens",
            "carrot.fill", "carrot"
        ]),
        ("music.note", "Музыка", "Music", [
            "music.note", "music.note.list", "music.quarternote.3",
            "music.mic", "music.mic.circle.fill",
            "guitars.fill", "guitars",
            "pianokeys", "pianokeys.inverse",
            "drum.fill", "drum",
            "headphones", "headphones.circle.fill",
            "earbuds", "earbuds.case.fill",
            "airpodspro", "airpodsmax",
            "hifispeaker.fill", "hifispeaker", "hifispeaker.2.fill",
            "homepodmini.fill", "homepodmini",
            "radio.fill", "radio",
            "waveform", "waveform.circle.fill", "waveform.path",
            "waveform.path.ecg", "waveform.badge.plus",
            "metronome.fill", "metronome",
            "tuningfork",
            "speaker.fill", "speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill",
            "speaker.slash.fill",
            "mic.fill", "mic", "mic.circle.fill", "mic.slash.fill",
            "music.note.tv.fill", "music.note.tv",
            "play.fill", "pause.fill", "stop.fill",
            "backward.fill", "forward.fill",
            "repeat", "repeat.1", "shuffle",
            "airplayaudio", "airplayaudio.circle.fill",
            "vinyl.fill", "opticaldisc.fill"
        ]),
        ("gamecontroller.fill", "Игры", "Games", [
            "gamecontroller.fill", "gamecontroller",
            "flag.checkered", "flag.checkered.circle.fill",
            "trophy.fill", "trophy", "trophy.circle.fill",
            "medal.fill", "medal",
            "target", "scope",
            "shield.fill", "shield", "shield.checkered",
            "shield.lefthalf.filled", "shield.righthalf.filled",
            "bolt.shield.fill",
            "soccerball", "soccerball.circle.fill",
            "basketball.fill", "basketball",
            "football.fill", "football",
            "tennisball.fill", "tennisball",
            "baseball.fill", "baseball",
            "cricket.ball.fill", "cricket.ball",
            "figure.run", "figure.run.circle.fill",
            "figure.skiing.downhill", "figure.skiing.crosscountry",
            "figure.surfing", "figure.swimming",
            "figure.basketball", "figure.soccer",
            "figure.tennis", "figure.golf",
            "figure.boxing", "figure.fencing",
            "figure.archery", "figure.climbing",
            "dumbbell.fill", "dumbbell",
            "sportscourt.fill", "sportscourt",
            "dice.fill", "puzzlepiece.fill", "puzzlepiece",
            "arcade.stick", "playstation.logo", "xbox.logo"
        ]),
        ("globe.americas.fill", "Космос", "Space", [
            "moon.fill", "moon", "moon.circle.fill",
            "moon.stars.fill", "moon.stars",
            "moon.haze.fill", "moon.haze",
            "sun.max.fill", "sun.max", "sun.max.circle.fill",
            "sun.min.fill", "sun.min",
            "sun.horizon.fill", "sun.horizon",
            "sunrise.fill", "sunrise",
            "sunset.fill", "sunset",
            "sparkle", "sparkles",
            "star.fill", "star", "star.circle.fill",
            "globe.americas.fill", "globe.americas",
            "globe.europe.africa.fill", "globe.europe.africa",
            "globe.asia.australia.fill", "globe.asia.australia",
            "globe.central.south.asia.fill",
            "globe.badge.chevron.backward",
            "airplane", "airplane.circle.fill",
            "rocket.fill", "rocket",
            "scope", "binoculars.fill", "binoculars",
            "tornado", "hurricane",
            "atom", "gyroscope",
            "light.beacon.fill", "light.beacon.min.fill"
        ]),
        ("cloud.fill", "Природа", "Nature", [
            "leaf.fill", "leaf", "leaf.circle.fill",
            "tree.fill", "tree",
            "mountain.2.fill", "mountain.2",
            "water.waves", "water.waves.slash",
            "wind", "wind.circle.fill",
            "cloud.fill", "cloud",
            "cloud.bolt.fill", "cloud.bolt",
            "cloud.bolt.rain.fill",
            "cloud.rain.fill", "cloud.rain",
            "cloud.heavyrain.fill",
            "cloud.drizzle.fill",
            "cloud.snow.fill", "cloud.snow",
            "cloud.hail.fill",
            "cloud.sleet.fill",
            "cloud.fog.fill",
            "cloud.sun.fill", "cloud.sun",
            "cloud.sun.rain.fill",
            "cloud.moon.fill", "cloud.moon",
            "cloud.moon.rain.fill",
            "snowflake", "snowflake.circle.fill",
            "flame.fill", "flame", "flame.circle.fill",
            "drop.fill", "drop", "drop.circle.fill",
            "sun.horizon.fill", "sun.horizon",
            "rainbow",
            "humidity.fill", "humidity",
            "thermometer.sun.fill", "thermometer.snowflake",
            "thermometer.medium",
            "aqi.low", "aqi.medium", "aqi.high",
            "carbon.dioxide.cloud.fill"
        ]),
        ("wrench.fill", "Предметы", "Objects", [
            "wrench.fill", "wrench", "wrench.and.screwdriver.fill",
            "hammer.fill", "hammer",
            "screwdriver.fill", "screwdriver",
            "paintbrush.fill", "paintbrush",
            "paintbrush.pointed.fill", "paintbrush.pointed",
            "pencil", "pencil.circle.fill", "pencil.tip",
            "pen.fill", "pen",
            "scissors", "scissors.circle.fill",
            "paperclip", "paperclip.circle.fill",
            "link", "link.circle.fill",
            "key.fill", "key", "key.horizontal.fill",
            "lock.fill", "lock", "lock.open.fill",
            "bell.fill", "bell", "bell.badge.fill",
            "flashlight.on.fill", "flashlight.off.fill",
            "camera.fill", "camera", "camera.circle.fill",
            "video.fill", "video",
            "cube.fill", "cube", "cube.transparent.fill",
            "shippingbox.fill", "shippingbox",
            "gift.fill", "gift",
            "hourglass", "hourglass.circle.fill",
            "timer", "timer.circle.fill",
            "lightbulb.fill", "lightbulb", "lightbulb.circle.fill",
            "lamp.desk.fill", "lamp.desk",
            "lamp.floor.fill", "lamp.table.fill",
            "fan.fill", "fan",
            "cup.and.saucer.fill", "cup.and.saucer",
            "mug.fill", "takeoutbag.and.cup.and.straw.fill",
            "fork.knife", "fork.knife.circle.fill",
            "wineglass.fill", "wineglass",
            "birthday.cake.fill", "birthday.cake",
            "party.popper.fill", "party.popper",
            "balloon.fill", "balloon", "balloon.2.fill",
            "bag.fill", "bag", "cart.fill", "cart",
            "creditcard.fill", "creditcard",
            "banknote.fill", "banknote",
            "phone.fill", "phone",
            "envelope.fill", "envelope",
            "book.fill", "book", "books.vertical.fill",
            "newspaper.fill", "newspaper",
            "graduationcap.fill", "graduationcap",
            "backpack.fill", "backpack",
            "suitcase.fill", "suitcase",
            "umbrella.fill", "umbrella"
        ]),
        ("arrow.right", "Стрелки", "Arrows", [
            "arrow.right", "arrow.left", "arrow.up", "arrow.down",
            "arrow.up.right", "arrow.up.left", "arrow.down.right", "arrow.down.left",
            "arrow.right.circle.fill", "arrow.left.circle.fill",
            "arrow.up.circle.fill", "arrow.down.circle.fill",
            "arrow.right.square.fill", "arrow.left.square.fill",
            "arrow.up.square.fill", "arrow.down.square.fill",
            "arrow.uturn.right", "arrow.uturn.left",
            "arrow.uturn.up", "arrow.uturn.down",
            "arrow.uturn.right.circle.fill",
            "arrow.clockwise", "arrow.counterclockwise",
            "arrow.clockwise.circle.fill",
            "arrow.2.squarepath",
            "arrow.triangle.2.circlepath", "arrow.triangle.2.circlepath.circle.fill",
            "arrow.trianglehead.right", "arrow.trianglehead.left",
            "arrow.trianglehead.up", "arrow.trianglehead.down",
            "arrow.trianglehead.counterclockwise",
            "arrowshape.right.fill", "arrowshape.left.fill",
            "arrowshape.up.fill", "arrowshape.down.fill",
            "arrowshape.turn.up.right.fill", "arrowshape.turn.up.left.fill",
            "arrowshape.zigzag.right.fill",
            "arrowshape.bounce.right.fill",
            "chevron.right", "chevron.left", "chevron.up", "chevron.down",
            "chevron.right.2", "chevron.left.2",
            "chevron.up.chevron.down",
            "paperplane.fill", "paperplane", "paperplane.circle.fill",
            "location.fill", "location", "location.circle.fill",
            "location.north.fill", "location.north.line.fill",
            "safari.fill", "safari",
            "arrow.up.message.fill",
            "cursorarrow.rays", "cursorarrow",
            "move.3d", "rotate.3d"
        ]),
        ("number", "Символы", "Symbols", [
            "infinity", "infinity.circle.fill",
            "number", "number.circle.fill",
            "x.squareroot", "sum", "percent",
            "plus", "minus", "multiply", "divide", "equal",
            "lessthan", "greaterthan",
            "dollarsign", "dollarsign.circle.fill",
            "eurosign", "eurosign.circle.fill",
            "sterlingsign", "sterlingsign.circle.fill",
            "yensign", "yensign.circle.fill",
            "bitcoinsign", "bitcoinsign.circle.fill",
            "rublesign", "rublesign.circle.fill",
            "turkishlirasign", "indianrupeesign",
            "atom", "waveform.path.ecg",
            "cross.fill", "cross", "cross.circle.fill",
            "staroflife.fill", "staroflife",
            "starofdavid.fill", "starofdavid",
            "hand.thumbsup.fill", "hand.thumbsup",
            "hand.thumbsdown.fill",
            "hand.point.right.fill", "hand.point.left.fill",
            "hand.point.up.fill", "hand.point.down.fill",
            "hand.wave.fill",
            "face.smiling.fill", "face.smiling",
            "face.dashed.fill",
            "peacesign",
            "questionmark", "questionmark.circle.fill",
            "exclamationmark", "exclamationmark.circle.fill", "exclamationmark.triangle.fill",
            "info.circle.fill", "info.circle",
            "at", "at.circle.fill",
            "number.square.fill",
            "character", "textformat",
            "abc", "textformat.abc"
        ]),
        ("person.fill", "Люди", "People", [
            "person.fill", "person", "person.circle.fill",
            "person.2.fill", "person.2", "person.2.circle.fill",
            "person.3.fill", "person.3",
            "person.crop.circle.fill",
            "person.crop.square.fill",
            "person.badge.plus", "person.badge.minus",
            "person.badge.clock.fill",
            "figure.stand", "figure.stand.line.dotted.figure.stand",
            "figure.walk", "figure.walk.circle.fill",
            "figure.run", "figure.run.circle.fill",
            "figure.roll", "figure.roll.runningpace",
            "figure.dance", "figure.wave",
            "figure.fall", "figure.jump",
            "figure.strengthtraining.traditional", "figure.strengthtraining.functional",
            "figure.yoga", "figure.pilates",
            "figure.skiing.downhill", "figure.skiing.crosscountry",
            "figure.snowboarding",
            "figure.surfing", "figure.swimming",
            "figure.water.fitness",
            "figure.basketball", "figure.soccer",
            "figure.tennis", "figure.golf",
            "figure.boxing", "figure.fencing",
            "figure.archery", "figure.climbing",
            "figure.fishing", "figure.hunting",
            "figure.equestrian.sports",
            "hand.raised.fill", "hand.raised", "hand.raised.circle.fill",
            "hand.thumbsup.fill", "hand.thumbsdown.fill",
            "hand.point.right.fill", "hand.point.left.fill",
            "hand.point.up.fill", "hand.point.down.fill",
            "hand.wave.fill", "hand.draw.fill",
            "hands.clap.fill", "hands.sparkles.fill",
            "brain.head.profile", "brain", "brain.fill",
            "eye.fill", "eye", "eye.circle.fill",
            "mouth.fill", "mouth",
            "ear.fill", "ear",
            "nose.fill", "nose"
        ]),
        ("desktopcomputer", "Техника", "Tech", [
            "desktopcomputer", "macbook", "laptopcomputer",
            "iphone", "iphone.circle.fill",
            "ipad", "ipad.landscape",
            "applewatch", "applewatch.watchface",
            "airpodspro", "airpodsmax", "earbuds",
            "homepodmini.fill", "homepod.fill",
            "appletv.fill", "appletv",
            "tv.fill", "tv", "tv.circle.fill",
            "display", "display.2",
            "keyboard.fill", "keyboard",
            "computermouse.fill", "computermouse",
            "printer.fill", "printer",
            "scanner.fill",
            "server.rack",
            "cpu.fill", "cpu",
            "memorychip.fill", "memorychip",
            "internaldrive.fill", "externaldrive.fill",
            "opticaldiscdrive.fill",
            "wifi", "wifi.circle.fill",
            "antenna.radiowaves.left.and.right",
            "antenna.radiowaves.left.and.right.circle.fill",
            "cable.connector", "cable.connector.horizontal",
            "battery.100", "battery.75", "battery.50", "battery.25",
            "bolt.batteryblock.fill",
            "power", "power.circle.fill",
            "powerplug.fill", "powerplug",
            "qrcode", "barcode",
            "simcard.fill", "simcard",
            "esim.fill",
            "sdcard.fill",
            "headphones", "headphones.circle.fill",
            "gamecontroller.fill"
        ]),
        ("house.fill", "Дом", "Home", [
            "house.fill", "house", "house.circle.fill",
            "house.lodge.fill", "house.lodge",
            "building.fill", "building",
            "building.2.fill", "building.2",
            "building.columns.fill", "building.columns",
            "door.left.hand.closed", "door.left.hand.open",
            "door.garage.closed", "door.garage.open",
            "window.vertical.closed",
            "bed.double.fill", "bed.double",
            "sofa.fill", "sofa",
            "chair.fill", "chair",
            "chair.lounge.fill",
            "bathtub.fill", "bathtub",
            "shower.fill", "shower",
            "toilet.fill", "toilet",
            "sink.fill",
            "washer.fill", "dryer.fill",
            "refrigerator.fill", "refrigerator",
            "oven.fill", "oven",
            "microwave.fill", "microwave",
            "cooktop.fill",
            "dishwasher.fill",
            "fan.ceiling.fill",
            "light.cylindrical.ceiling.fill",
            "lamp.desk.fill", "lamp.floor.fill", "lamp.table.fill",
            "lightswitch.on.fill",
            "poweroutlet.type.b.fill",
            "spigot.fill", "spigot",
            "drop.fill", "flame.fill"
        ])
    ]

    private var allSymbols: [String] {
        var result = [String]()
        for cat in Self.categoryData where cat.nameEN != "Recent" {
            result.append(contentsOf: cat.symbols)
        }
        return Array(Set(result)).sorted()
    }

    private var recentSymbols: [String] {
        let saved = UserDefaults.standard.stringArray(forKey: "recentSliderSymbols") ?? []
        return saved
    }

    private func addToRecent(_ symbol: String) {
        var recent = UserDefaults.standard.stringArray(forKey: "recentSliderSymbols") ?? []
        recent.removeAll { $0 == symbol }
        recent.insert(symbol, at: 0)
        if recent.count > 16 { recent = Array(recent.prefix(16)) }
        UserDefaults.standard.set(recent, forKey: "recentSliderSymbols")
    }

    private var displaySymbols: [String] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            return allSymbols.filter { $0.lowercased().contains(query) }
        }
        if selectedCategory == 0 {
            return recentSymbols
        }
        return Self.categoryData[selectedCategory].symbols
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if !isSearching {
                        // Category picker (glass style)
                        GlassEffectContainer {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(0..<Self.categoryData.count, id: \.self) { index in
                                        let cat = Self.categoryData[index]
                                        let isSelected = selectedCategory == index
                                        Button {
                                            withAnimation(.smooth(duration: 0.3)) {
                                                selectedCategory = index
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 11, weight: .medium))
                                                Text(theme.language == .russian ? cat.nameRU : cat.nameEN)
                                                    .font(.custom(
                                                        isSelected ? Loc.fontBold : Loc.fontMedium,
                                                        size: 12
                                                    ))
                                                    .lineLimit(1)
                                            }
                                            .foregroundStyle(
                                                isSelected ? theme.currentTheme.accent : .secondary
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .glassEffect(
                                                isSelected
                                                    ? .regular.tint(theme.currentTheme.accent.opacity(0.2)).interactive()
                                                    : .identity,
                                                in: .capsule
                                            )
                                            .glassEffectID(String(index), in: categoryNamespace)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                                .glassEffect(in: .capsule)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .sensoryFeedback(.selection, trigger: selectedCategory)
                    }

                    // Content
                    if displaySymbols.isEmpty && selectedCategory == 0 && !isSearching {
                        emptyRecent
                    } else if displaySymbols.isEmpty && isSearching {
                        directInputView
                    } else {
                        symbolGridView
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search symbols"
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: theme.activeSliderSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                        Text(Loc.sliderIcon)
                            .font(.custom(Loc.fontBold, size: 17))
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyRecent: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(theme.language == .russian ? "Нет недавних" : "No recent symbols")
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var directInputView: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        return VStack(spacing: 16) {
            if UIImage(systemName: trimmed) != nil {
                Button {
                    selectSymbol(trimmed)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: trimmed)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(theme.currentTheme.accent)
                        Text(trimmed)
                            .font(.custom(Loc.fontMedium, size: 13))
                            .foregroundStyle(.secondary)
                        Text(theme.language == .russian ? "Нажмите, чтобы выбрать" : "Tap to select")
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(theme.language == .russian ? "Ничего не найдено" : "No results")
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var symbolGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(displaySymbols, id: \.self) { symbol in
                Button {
                    selectSymbol(symbol)
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.customSliderSymbol == symbol
                                    ? theme.currentTheme.accent.opacity(0.2)
                                    : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    theme.customSliderSymbol == symbol
                                        ? theme.currentTheme.accent
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .foregroundStyle(
                            theme.customSliderSymbol == symbol
                                ? theme.currentTheme.accent
                                : .primary
                        )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: theme.customSliderSymbol)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func selectSymbol(_ symbol: String) {
        theme.customSliderSymbol = symbol
        theme.sliderIcon = .custom
        addToRecent(symbol)
    }
}
