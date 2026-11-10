import Foundation

enum DalilCopy {
    static func t(_ key: String, _ language: AppLanguage) -> String {
        (language == .arabic ? ar : en)[key] ?? key
    }

    static func exitLabel(_ number: String, _ language: AppLanguage) -> String {
        language == .arabic ? "مخرج \(number)" : "Exit \(number)"
    }

    static func meters(_ value: Int, _ language: AppLanguage) -> String {
        language == .arabic ? "\(value) م" : "\(value) m"
    }

    static func minutes(_ value: Int, _ language: AppLanguage) -> String {
        if language == .arabic {
            return value == 1 ? "دقيقة" : "\(value) دقائق"
        }
        return value == 1 ? "1 min" : "\(value) min"
    }

    static func shortMinutes(_ value: Int, _ language: AppLanguage) -> String {
        language == .arabic ? "\(value) د" : "\(value) min"
    }

    static func stops(_ value: Int, _ language: AppLanguage) -> String {
        guard language == .arabic else { return value == 1 ? "1 stop" : "\(value) stops" }
        switch value {
        case 1: return "محطة واحدة"
        case 2: return "محطتان"
        case 3...10: return "\(value) محطات"
        default: return "\(value) محطة"
        }
    }

    static func results(_ value: Int, _ language: AppLanguage) -> String {
        guard language == .arabic else { return value == 1 ? "1 result" : "\(value) results" }
        switch value {
        case 0: return "لا توجد نتائج"
        case 1: return "نتيجة واحدة"
        case 2: return "نتيجتان"
        case 3...10: return "\(value) نتائج"
        default: return "\(value) نتيجة"
        }
    }

    static func walkUpTo(_ minutes: Int, _ language: AppLanguage) -> String {
        language == .arabic ? "حتى \(minutes) د مشي" : "≤ \(minutes) min walk"
    }

    static func compactDistance(_ value: Int, _ language: AppLanguage) -> String {
        if value >= 1000 {
            let km = Double(value) / 1000
            let formatted = String(format: "%.1f", km)
            let localized = language == .arabic ? formatted.replacingOccurrences(of: ".", with: "٫") : formatted
            return language == .arabic ? "\(localized) كم" : "\(localized) km"
        }
        return meters(value, language)
    }

    static func walkAndDistance(minutes: Int, meters distance: Int, _ language: AppLanguage) -> String {
        let walk = shortMinutes(minutes, language)
        let compact = compactDistance(distance, language)
        return language == .arabic ? "\(walk) مشي · \(compact)" : "\(walk) walk · \(compact)"
    }

    static func toward(_ destination: String, _ language: AppLanguage) -> String {
        language == .arabic ? "باتجاه \(destination)" : "Toward \(destination)"
    }

    static func thenMinutes(_ values: [Int], _ language: AppLanguage) -> String {
        let rest = values.dropFirst().prefix(2).map(String.init).joined(separator: " · ")
        guard !rest.isEmpty else { return "" }
        return language == .arabic ? "ثم \(rest)" : "then \(rest)"
    }

    static func walkFromStation(minutes: Int, station: String, _ language: AppLanguage) -> String {
        let walk = shortMinutes(minutes, language)
        return language == .arabic ? "\(walk) مشي من \(station)" : "\(walk) walk from \(station)"
    }

    static func tripRide(line: String, toward: String, next: Int, stops: Int, _ language: AppLanguage) -> String {
        let wait = shortMinutes(next, language)
        if language == .arabic {
            return "المسار \(line) باتجاه \(toward) · القطار القادم \(wait) · \(stops) محطات"
        }
        return "\(line) line toward \(toward) · next train \(wait) · \(stops) stops"
    }

    static func tripRideCompact(line: String, toward: String, stops: Int, _ language: AppLanguage) -> String {
        language == .arabic
            ? "\(line) باتجاه \(toward) · \(stops) محطات"
            : "\(line) toward \(toward) · \(stops) stops"
    }

    static func tripNowRide(line: String, toward: String, _ language: AppLanguage) -> String {
        language == .arabic
            ? "الحين اركب \(line) باتجاه \(toward)"
            : "Now board \(line) toward \(toward)"
    }

    static func tripNowTransfer(line: String, toward: String, _ language: AppLanguage) -> String {
        language == .arabic
            ? "الحين حوّل إلى \(line) باتجاه \(toward)"
            : "Now change to \(line) toward \(toward)"
    }

    static func tripNowWalk(_ dest: String, _ language: AppLanguage) -> String {
        language == .arabic ? "الحين امشِ إلى \(dest)" : "Now walk to \(dest)"
    }

    static func tripNowAlightWalk(_ dest: String, _ language: AppLanguage) -> String {
        language == .arabic
            ? "الحين انزل وامشِ إلى \(dest)"
            : "Now get off and walk to \(dest)"
    }

    static func nearStation(_ station: String, minutes: Int, _ language: AppLanguage) -> String {
        language == .arabic
            ? "قرب \(station) · \(minutes) دقائق"
            : "Near \(station) · \(minutes) min"
    }

    static func leaveExit(_ number: String, _ language: AppLanguage) -> String {
        language == .arabic ? "اخرج من مخرج \(number)" : "Take Exit \(number)"
    }

    static func walkToward(_ minutes: Int, meters: Int, _ language: AppLanguage) -> String {
        language == .arabic
            ? "امشِ نحو المكان حوالي \(minutes) دقائق (\(meters) م)."
            : "Walk toward the place for about \(minutes) min (\(meters) m)."
    }

    static func accessLine(exit: String?, minutes: Int, meters: Int, _ language: AppLanguage) -> String {
        let walk = Self.minutes(minutes, language)
        let distance = language == .arabic ? "\(meters) م" : "\(meters) m"
        if let exit, !exit.isEmpty {
            let gate = language == .arabic ? "مخرج \(exit)" : "Exit \(exit)"
            return "\(gate) · \(walk) · \(distance)"
        }
        return "\(walk) · \(distance)"
    }

    static func greeting(_ language: AppLanguage, hour: Int = Calendar.current.component(.hour, from: Date())) -> String {
        let key: String
        if hour < 12 {
            key = "home.hello.morning"
        } else if hour < 18 {
            key = "home.hello.afternoon"
        } else {
            key = "home.hello.evening"
        }
        return t(key, language)
    }

    private static let ar: [String: String] = [
        "brand": "دليل",
        "splash.tagline": "انزل المحطة، واتبع دليلك",
        "home.hello": "أهلاً، الرياض",
        "home.hello.morning": "صباح الخير، الرياض",
        "home.hello.afternoon": "أهلاً، الرياض",
        "home.hello.evening": "مساء الخير، الرياض",
        "home.hello.sub": "انزل المحطة، واتبع دليلك لوجهتك",
        "home.metroLive": "المترو يعمل",
        "status.running": "المترو يعمل",
        "status.closed": "المترو متوقف",
        "status.disrupted": "خلل في الخدمة",
        "status.untilMidnight": "حتى ١٢ م",
        "status.opensMorning": "يفتح ٦ ص",
        "status.sheet.title": "حالة الخدمة",
        "status.hours": "٦:٠٠ ص — ١٢:٠٠ م",
        "status.sheet.body": "أوقات المغادرة تقديرية حتى يتوفر الجدول الرسمي.",
        "home.details": "التفاصيل",
        "home.station.expand": "عرض المغادرات",
        "home.station.collapse": "إخفاء المغادرات",
        "home.quick.home": "المنزل",
        "home.quick.work": "العمل",
        "home.quick.add": "أضف موقع",
        "home.quick.addHome": "أضف المنزل",
        "home.quick.addWork": "أضف العمل",
        "saved.title": "مواقعي",
        "saved.saveTitle": "احفظ هذا الموقع",
        "saved.saveHome": "حفظ كمنزل",
        "saved.saveWork": "حفظ كعمل",
        "saved.saveCustom": "اسم مخصص",
        "saved.customPlaceholder": "مثل: بيت أهلي",
        "saved.save": "حفظ",
        "saved.rename": "إعادة التسمية",
        "saved.move": "نقل على الخريطة",
        "saved.delete": "حذف",
        "saved.unnamed": "موقع محفوظ",
        "saved.editHint": "اضغط مطولاً للتعديل أو النقل",
        "saved.useHint": "خطّط الرحلة من مكانك الحالي",
        "saved.planHint": "خطّط الرحلة إلى هنا",
        "map.pickHome": "اضغط على الخريطة لتحديد المنزل",
        "map.pickWork": "اضغط على الخريطة لتحديد العمل",
        "map.pickSaved": "اضغط على الخريطة لتحديد الموقع",
        "map.pickMove": "اضغط على الموقع الجديد",
        "home.browseBy": "تصفح حسب الفئة",
        "depart.toward": "باتجاه",
        "place.near": "قرب",
        "home.search": "إلى أين تريد الذهاب؟",
        "search.recent": "آخر البحث",
        "search.clear": "مسح",
        "home.useLocation": "استخدم موقعي الحالي",
        "home.cat.stations": "محطات",
        "home.cat.tourism": "سياحة",
        "home.cat.parks": "حدائق",
        "home.cat.clubs": "نوادي",
        "home.cat.stations.sub": "شبكة المترو",
        "home.cat.tourism.sub": "معالم قريبة",
        "home.cat.parks.sub": "حدائق ومناظر",
        "home.cat.clubs.sub": "جيم ونادي",
        "home.explore": "تصفح",
        "home.nearbyPlaces": "أماكن قريبة",
        "home.openStation": "افتح المحطة",
        "browse.empty": "ما لقينا أماكن بهالتصنيف بعد.",
        "home.nearest": "أقرب محطة إليك",
        "home.activeRoute": "المسار النشط",
        "home.fromHere": "من موقعك الحالي",
        "home.walkExit": "امشِ إلى المحطة ثم اتبع دليل المخرج",
        "home.route": "المسار",
        "home.follow": "اتبع الدليل ثم اخرج من أقرب مخرج",
        "home.follow.sub": "دليل المخرج من المحطة إلى الشارع",
        "home.saved": "أماكن محفوظة",
        "home.savedEmpty": "احفظ وجهة لتظهر هنا.",
        "home.nearbyEmpty": "ما فيه أماكن قريبة بعد.",
        "home.go": "انطلق",
        "home.seeAll": "عرض الكل",
        "map.title": "الخريطة",
        "map.search": "ابحث عن وجهة أو محطة...",
        "map.all": "الكل",
        "map.cafes": "مقاهي",
        "map.restaurants": "مطاعم",
        "map.nature": "طبيعة",
        "map.clubs": "نوادي",
        "map.pharmacies": "صيدليات",
        "cat.gym": "نادي",
        "cat.pharmacy": "صيدلية",
        "account.myPlaces": "أماكني",
        "account.nearestStation": "أقرب محطة",
        "account.contributions": "مساهماتي",
        "account.aboutSection": "عن دليل",
        "account.version": "الإصدار",
        "account.signOut.failed": "ما قدرنا نسجّل خروجك. حاول مرة ثانية.",
        "account.delete.body": "حذف الحساب يمسح أماكنك المحفوظة وإضافاتك وبلاغاتك نهائياً، وما يمديك ترجعها.",
        "account.delete.failed": "ما قدرنا نحذف الحساب. تأكد من الاتصال وحاول مرة ثانية.",
        "common.ok": "حسناً",
        "role.guest": "زائر",
        "role.user": "مستخدم",
        "role.moderator": "مشرف",
        "role.admin": "مدير",
        "browse.sort": "الترتيب",
        "browse.sort.walk": "الأقرب مشياً",
        "browse.sort.me": "الأقرب لي",
        "browse.nearStation": "قرب محطتي",
        "browse.filtered.empty": "ما فيه نتائج بهالفلاتر. جرّب وقت مشي أطول.",
        "account.made": "صُنع للاستكشاف من محطات مترو الرياض",
        "walk.step2": "امشِ نحو المكان",
        "walk.arrive": "الوصول إلى المكان",
        "walk.step1.station": "اخرج من المحطة",
        "walk.exit.followSign": "اتبع لافتة المخرج داخل المحطة، ثم اخرج للشارع.",
        "favorites.title": "رحلاتي",
        "favorites.saved": "المحفوظة",
        "favorites.signedOut.title": "احفظ أماكنك",
        "favorites.signedOut.body": "سجّل دخولك عشان ترجع لنفس الأماكن من أي جهاز.",
        "favorites.empty.title": "ما فيه محفوظات بعد",
        "favorites.empty.body": "من صفحة المكان اضغط الإشارة عشان تحفظه هنا.",
        "favorites.suggest": "احفظ من القريب منك",
        "favorites.signedOut.short": "احفظ الأماكن اللي تعجبك وترجع لها من أي جهاز.",
        "place.photos": "صور",
        "place.openNow": "مفتوح الآن",
        "place.reviews": "تقييم",
        "place.nearestStation": "المحطة",
        "place.walk.short": "المشي",
        "place.distance": "المسافة",
        "station.exits.updating.short": "المخارج قيد التحديث",
        "place.walk.title": "خطوات المشي",
        "place.walk.live": "مسار حي",
        "place.about": "نبذة عن المكان",
        "place.amenities": "المميزات",
        "place.tip.title": "نصيحة",
        "place.tip.body": "اتبع المخرج الأقرب ثم امشِ في الشارع مباشرة.",
        "place.inside.title": "داخل المحطة",
        "place.googleAttribution": "خرائط ومسارات من مصادر مفتوحة.",
        "place.walk.start": "بدء المشي",
        "place.plan": "خطّط الرحلة",
        "trip.title": "خطّة الرحلة",
        "trip.start": "ابدأ الرحلة",
        "trip.you": "موقعك",
        "trip.walkStation": "امشِ إلى المحطة",
        "trip.ride": "اركب القطار",
        "trip.alight": "انزل في المحطة",
        "trip.transfer": "حوّل في المحطة",
        "trip.headTo": "توجه إلى المحطة",
        "trip.exit": "اخرج من المخرج",
        "trip.arrive": "الوصول إلى المكان",
        "trip.arrived": "وصلت",
        "trip.end": "إنهاء الرحلة",
        "trip.nowAlight": "الحين انزل من المحطة",
        "trip.next": "الخطوة التالية",
        "trip.change": "حوّل",
        "map.nearest": "أقرب محطة",
        "map.locate": "موقعي",
        "map.pickHint": "اضغط على الخريطة لتحديد موقعك",
        "map.youAreHere": "موقعك",
        "map.layers": "الطبقات",
        "map.hidePlaces": "إخفاء الأماكن",
        "station.seg.departures": "المغادرات",
        "station.seg.exits": "المخارج",
        "station.seg.nearby": "بالقرب",
        "station.exits.empty": "ما فيه مخارج موثّقة بعد.",
        "account.signInPrompt": "سجّل الدخول لحفظ أماكنك",
        "account.about": "عن التطبيق",
        "place.walk.active": "المسار نشط",
        "place.walk.metroMap": "الخريطة",
        "place.report": "الإبلاغ عن خطأ",
        "place.details.title": "تفاصيل الوجهة",
        "place.accessible": "مناسب للكرسي",
        "cat.cafe": "مقهى",
        "cat.restaurant": "مطعم",
        "cat.dessert": "حلويات",
        "cat.nature": "طبيعة",
        "cat.place": "وجهة",
        "tab.home": "الرئيسية",
        "tab.map": "الخريطة",
        "tab.favorites": "رحلاتي",
        "tab.account": "الحساب",
        "tab.search": "بحث",
        "search.cancel": "إلغاء",
        "search.nearbyStations": "محطات قريبة",
        "search.stations": "محطات",
        "search.places": "أماكن",
        "search.browse": "تصفح",
        "search.empty.suggest": "ما لقينا نتيجة — جرّب «محطة جامعة الملك سعود» أو «حديقة»",
        "place.save": "حفظ",
        "place.share": "مشاركة",
        "account.title": "الحساب",
        "account.language": "اللغة",
        "account.appearance": "المظهر",
        "lang.ar": "العربية",
        "lang.en": "English",
        "appearance.light": "فاتح",
        "appearance.dark": "ليلي",
        "appearance.system": "النظام",
        "account.notifications": "التنبيهات",
        "account.signOut": "تسجيل الخروج",
        "account.delete": "حذف الحساب",
        "auth.signIn": "تسجيل الدخول",
        "account.preferences": "التفضيلات",
        "account.submissions": "إضافاتي",
        "account.reports": "بلاغاتي",
        "account.privacy": "الخصوصية",
        "account.sources": "المصادر",
        "account.support": "الدعم",
        "station.nearby": "أماكن قرب هذه المحطة",
        "station.inside": "داخل المحطة",
        "station.connected": "متصل مباشرة",
        "station.exits.title": "المخارج",
        "station.exits.ready": "مخارج موثّقة لهذه المحطة",
        "station.exits.updating": "المخارج قيد التحديث",
        "station.coords.official": "إحداثيات رسمية",
        "station.coords.approx": "إحداثيات تقريبية",
        "station.facilities": "الخدمات",
        "facility.parking": "مواقف",
        "facility.prayerRoom": "مصلى",
        "facility.retail": "محلات",
        "facility.customerService": "خدمة العملاء",
        "facility.restroom": "دورات مياه",
        "state.empty.section": "ما فيه عناصر هنا بعد.",
        "account.visits": "وجهة زرتها",
        "account.routes": "مسارات محفوظة",
        "account.ratings": "تقييماً",
        "home.worth": "يستحق الوقفة",
        "home.work": "مناسب للشغل",
        "home.sitting": "جلسة مريحة",
        "home.food": "أكل وشرب",
        "onboarding.1.title": "اكتشف الأماكن قرب المحطات",
        "onboarding.1.body": "مطاعم ومقاهي وجلسات مرتبطة بمحطات مترو الرياض، مع تطبيق ملاحة.",
        "onboarding.2.title": "اتبع المخرج ثم امشِ",
        "onboarding.2.body": "دليل المخرج من المحطة إلى الشارع، ثم أقصر مسار مشي.",
        "onboarding.3.title": "حفظ المسارات",
        "onboarding.3.body": "احفظ الوجهة وارجع لها في أي وقت.",
        "onboarding.next": "التالي",
        "onboarding.start": "ابدأ",
    ]

    private static let en: [String: String] = [
        "brand": "Dalil",
        "splash.tagline": "Exit the station, then follow Dalil",
        "home.hello": "Hello, Riyadh",
        "home.hello.morning": "Good morning, Riyadh",
        "home.hello.afternoon": "Hello, Riyadh",
        "home.hello.evening": "Good evening, Riyadh",
        "home.hello.sub": "Exit the station, then follow Dalil to your place",
        "home.metroLive": "Metro is running",
        "status.running": "Metro is running",
        "status.closed": "Metro is closed",
        "status.disrupted": "Service disruption",
        "status.untilMidnight": "until 12 AM",
        "status.opensMorning": "opens 6 AM",
        "status.sheet.title": "Service status",
        "status.hours": "6:00 AM — 12:00 AM",
        "status.sheet.body": "Departure times are estimates until the official timetable is available.",
        "home.details": "Details",
        "home.station.expand": "Show departures",
        "home.station.collapse": "Hide departures",
        "home.quick.home": "Home",
        "home.quick.work": "Work",
        "home.quick.add": "Add place",
        "home.quick.addHome": "Add home",
        "home.quick.addWork": "Add work",
        "saved.title": "My places",
        "saved.saveTitle": "Save this location",
        "saved.saveHome": "Save as Home",
        "saved.saveWork": "Save as Work",
        "saved.saveCustom": "Custom name",
        "saved.customPlaceholder": "e.g. Family house",
        "saved.save": "Save",
        "saved.rename": "Rename",
        "saved.move": "Move on map",
        "saved.delete": "Delete",
        "saved.unnamed": "Saved place",
        "saved.editHint": "Touch and hold to rename or move",
        "saved.useHint": "Plan a trip from where you are",
        "saved.planHint": "Plan a trip here",
        "map.pickHome": "Tap the map to set Home",
        "map.pickWork": "Tap the map to set Work",
        "map.pickSaved": "Tap the map to set this place",
        "map.pickMove": "Tap the new location",
        "home.browseBy": "Browse by category",
        "depart.toward": "Toward",
        "place.near": "near",
        "home.search": "Where do you want to go?",
        "search.recent": "Recent searches",
        "search.clear": "Clear",
        "home.useLocation": "Use my current location",
        "home.cat.stations": "Stations",
        "home.cat.tourism": "Tourism",
        "home.cat.parks": "Parks",
        "home.cat.clubs": "Clubs",
        "home.cat.stations.sub": "Metro network",
        "home.cat.tourism.sub": "Nearby landmarks",
        "home.cat.parks.sub": "Parks and views",
        "home.cat.clubs.sub": "Gyms nearby",
        "home.explore": "Browse",
        "home.nearbyPlaces": "Nearby places",
        "home.openStation": "Open station",
        "browse.empty": "No places in this category yet.",
        "home.nearest": "Nearest station",
        "home.activeRoute": "Active route",
        "home.fromHere": "From your location",
        "home.walkExit": "Follow the exit guide from the station",
        "home.route": "Route",
        "home.follow": "Follow Dalil, then leave from the nearest exit",
        "home.follow.sub": "Exit guidance from the station to the street",
        "home.saved": "Saved places",
        "home.savedEmpty": "Save a place to see it here.",
        "home.nearbyEmpty": "No nearby places yet.",
        "home.go": "Go",
        "home.seeAll": "See all",
        "map.title": "Map",
        "map.search": "Search a place or station...",
        "map.all": "All",
        "map.cafes": "Cafes",
        "map.restaurants": "Restaurants",
        "map.nature": "Nature",
        "map.clubs": "Gyms",
        "map.pharmacies": "Pharmacies",
        "cat.gym": "Gym",
        "cat.pharmacy": "Pharmacy",
        "account.myPlaces": "My places",
        "account.nearestStation": "Nearest station",
        "account.contributions": "Contributions",
        "account.aboutSection": "About Dalil",
        "account.version": "Version",
        "account.signOut.failed": "Couldn't sign you out. Please try again.",
        "account.delete.body": "Deleting your account permanently removes your saved places, submissions and reports. This can't be undone.",
        "account.delete.failed": "Couldn't delete your account. Check your connection and try again.",
        "common.ok": "OK",
        "role.guest": "Guest",
        "role.user": "Member",
        "role.moderator": "Moderator",
        "role.admin": "Admin",
        "browse.sort": "Sort",
        "browse.sort.walk": "Shortest walk",
        "browse.sort.me": "Nearest to me",
        "browse.nearStation": "Near my station",
        "browse.filtered.empty": "No results with these filters. Try a longer walk.",
        "account.made": "Made for exploring from Riyadh Metro stations",
        "walk.step2": "Walk to the place",
        "walk.arrive": "Arrive at the place",
        "walk.step1.station": "Leave the station",
        "walk.exit.followSign": "Follow the exit sign inside the station, then walk out to the street.",
        "favorites.title": "My trips",
        "favorites.saved": "Saved",
        "favorites.signedOut.title": "Save your places",
        "favorites.signedOut.body": "Sign in to keep the same places on any device.",
        "favorites.empty.title": "Nothing saved yet",
        "favorites.empty.body": "Open a place and tap the bookmark to keep it here.",
        "favorites.suggest": "Save something nearby",
        "favorites.signedOut.short": "Keep the places you like and come back to them on any device.",
        "place.photos": "photos",
        "place.openNow": "Open now",
        "place.reviews": "reviews",
        "place.nearestStation": "Station",
        "place.walk.short": "Walk",
        "place.distance": "Distance",
        "station.exits.updating.short": "Exits updating",
        "place.walk.title": "Walking steps",
        "place.walk.live": "Live route",
        "place.about": "About this place",
        "place.amenities": "Amenities",
        "place.tip.title": "Tip",
        "place.tip.body": "Use the nearest exit, then walk straight on the street.",
        "place.inside.title": "Inside the station",
        "place.googleAttribution": "Maps and routes from open sources.",
        "place.walk.start": "Start walking",
        "place.plan": "Plan trip",
        "trip.title": "Trip plan",
        "trip.start": "Start trip",
        "trip.you": "Your location",
        "trip.walkStation": "Walk to the station",
        "trip.ride": "Board the train",
        "trip.alight": "Get off at the station",
        "trip.transfer": "Change at the station",
        "trip.headTo": "Head to the station",
        "trip.exit": "Leave from the exit",
        "trip.arrive": "Arrive at the place",
        "trip.arrived": "You arrived",
        "trip.end": "End trip",
        "trip.nowAlight": "Now get off at the station",
        "trip.next": "Next step",
        "trip.change": "Change",
        "map.nearest": "Nearest station",
        "map.locate": "My location",
        "map.pickHint": "Tap the map to set your location",
        "map.youAreHere": "You are here",
        "map.layers": "Layers",
        "map.hidePlaces": "Hide places",
        "station.seg.departures": "Departures",
        "station.seg.exits": "Exits",
        "station.seg.nearby": "Nearby",
        "station.exits.empty": "No verified exits yet.",
        "account.signInPrompt": "Sign in to save your places",
        "account.about": "About",
        "place.walk.active": "Route active",
        "place.walk.metroMap": "Map",
        "place.report": "Report a problem",
        "place.details.title": "Place details",
        "place.accessible": "Wheelchair accessible",
        "cat.cafe": "Cafe",
        "cat.restaurant": "Restaurant",
        "cat.dessert": "Dessert",
        "cat.nature": "Nature",
        "cat.place": "Place",
        "tab.home": "Home",
        "tab.map": "Map",
        "tab.favorites": "My trips",
        "tab.account": "Account",
        "tab.search": "Search",
        "search.cancel": "Cancel",
        "search.nearbyStations": "Nearby stations",
        "search.stations": "Stations",
        "search.places": "Places",
        "search.browse": "Browse",
        "search.empty.suggest": "No results — try “King Saud University Station” or “park”",
        "place.save": "Save",
        "place.share": "Share",
        "account.title": "Account",
        "account.language": "Language",
        "account.appearance": "Appearance",
        "lang.ar": "العربية",
        "lang.en": "English",
        "appearance.light": "Light",
        "appearance.dark": "Dark",
        "appearance.system": "System",
        "account.notifications": "Notifications",
        "account.signOut": "Sign out",
        "account.delete": "Delete account",
        "auth.signIn": "Sign in",
        "account.preferences": "Preferences",
        "account.submissions": "My submissions",
        "account.reports": "My reports",
        "account.privacy": "Privacy",
        "account.sources": "Sources",
        "account.support": "Support",
        "station.nearby": "Places near this station",
        "station.inside": "Inside the station",
        "station.connected": "Directly connected",
        "station.exits.title": "Exits",
        "station.exits.ready": "Verified exits for this station",
        "station.exits.updating": "Exits are being updated",
        "station.coords.official": "Official coordinates",
        "station.coords.approx": "Approximate coordinates",
        "station.facilities": "Facilities",
        "facility.parking": "Parking",
        "facility.prayerRoom": "Prayer room",
        "facility.retail": "Retail",
        "facility.customerService": "Customer service",
        "facility.restroom": "Restrooms",
        "state.empty.section": "Nothing here yet.",
        "account.visits": "places visited",
        "account.routes": "saved routes",
        "account.ratings": "ratings",
        "home.worth": "Worth the stop",
        "home.work": "Work friendly",
        "home.sitting": "Good seating",
        "home.food": "Food and drink",
        "onboarding.1.title": "Discover places near stations",
        "onboarding.1.body": "Restaurants, cafes, and sitting spots tied to Riyadh Metro, with walking guidance.",
        "onboarding.2.title": "Follow the exit, then walk",
        "onboarding.2.body": "Exit guidance from the station to the street, then the shortest walk.",
        "onboarding.3.title": "Save your routes",
        "onboarding.3.body": "Save a place and come back to it anytime.",
        "onboarding.next": "Next",
        "onboarding.start": "Start",
    ]
}
