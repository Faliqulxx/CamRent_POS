enum PaperWidth {
  width58mm,
  width80mm,
}

enum LogoSize {
  kecil, // 90px
  sedang, // 130px
  besar, // 180px
}

class BluetoothDeviceModel {
  final String name;
  final String address;
  final bool isPaired;

  const BluetoothDeviceModel({
    required this.name,
    required this.address,
    this.isPaired = true,
  });
}

class PresetLogoModel {
  final String id;
  final String name;
  final String assetPath;
  final String iconDescription;

  const PresetLogoModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.iconDescription,
  });
}

class PrinterConfigModel {
  static const List<PresetLogoModel> presetLogos = [
    PresetLogoModel(
      id: 'default',
      name: 'CampRent',
      assetPath: 'assets/images/camprent_logo.jpg',
      iconDescription: 'Gunung & Tenda Bawaan',
    ),
    PresetLogoModel(
      id: 'mountain',
      name: 'Summit Mountain',
      assetPath: 'assets/icons/logo_mountain.jpg',
      iconDescription: 'Puncak Gunung Garis Bersih',
    ),
    PresetLogoModel(
      id: 'tent',
      name: 'Vintage Tent',
      assetPath: 'assets/icons/logo_tent.jpg',
      iconDescription: 'Tenda & Hutan Pinus',
    ),
    PresetLogoModel(
      id: 'compass',
      name: 'Adventure Compass',
      assetPath: 'assets/icons/logo_compass.jpg',
      iconDescription: 'Mawar Kompas Navigasi',
    ),
  ];

  final String? selectedPrinterName;
  final String? selectedPrinterAddress;
  final bool isConnected;
  final PaperWidth paperWidth;
  final int charsPerLine;
  final bool autoCut;
  final bool autoPrint;
  final int copies;
  final int bottomMarginLines;
  final String codePage;

  // Struk Customization Fields
  final bool showLogo;
  final String selectedLogoId; // 'default', 'mountain', 'tent', 'compass', 'custom'
  final String? customLogoBase64;
  final LogoSize logoSize;
  final bool showQrCode;
  final bool showTerms;

  const PrinterConfigModel({
    this.selectedPrinterName = 'RPP02N-Thermal-58mm',
    this.selectedPrinterAddress = '66:22:33:44:55:66',
    this.isConnected = true,
    this.paperWidth = PaperWidth.width58mm,
    this.charsPerLine = 32,
    this.autoCut = false,
    this.autoPrint = true,
    this.copies = 1,
    this.bottomMarginLines = 3,
    this.codePage = 'CP858 (Euro)',
    this.showLogo = true,
    this.selectedLogoId = 'default',
    this.customLogoBase64,
    this.logoSize = LogoSize.sedang,
    this.showQrCode = true,
    this.showTerms = true,
  });

  int get effectiveCharsPerLine {
    if (paperWidth == PaperWidth.width58mm) {
      return 32;
    } else {
      return 48;
    }
  }

  double get logoDisplayWidth {
    switch (logoSize) {
      case LogoSize.kecil:
        return 80.0;
      case LogoSize.sedang:
        return 120.0;
      case LogoSize.besar:
        return 160.0;
    }
  }

  String get effectiveLogoAsset {
    final match = presetLogos.firstWhere(
      (l) => l.id == selectedLogoId,
      orElse: () => presetLogos.first,
    );
    return match.assetPath;
  }

  PrinterConfigModel copyWith({
    String? selectedPrinterName,
    String? selectedPrinterAddress,
    bool? isConnected,
    PaperWidth? paperWidth,
    int? charsPerLine,
    bool? autoCut,
    bool? autoPrint,
    int? copies,
    int? bottomMarginLines,
    String? codePage,
    bool? showLogo,
    String? selectedLogoId,
    String? customLogoBase64,
    LogoSize? logoSize,
    bool? showQrCode,
    bool? showTerms,
  }) {
    return PrinterConfigModel(
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
      selectedPrinterAddress: selectedPrinterAddress ?? this.selectedPrinterAddress,
      isConnected: isConnected ?? this.isConnected,
      paperWidth: paperWidth ?? this.paperWidth,
      charsPerLine: charsPerLine ?? this.charsPerLine,
      autoCut: autoCut ?? this.autoCut,
      autoPrint: autoPrint ?? this.autoPrint,
      copies: copies ?? this.copies,
      bottomMarginLines: bottomMarginLines ?? this.bottomMarginLines,
      codePage: codePage ?? this.codePage,
      showLogo: showLogo ?? this.showLogo,
      selectedLogoId: selectedLogoId ?? this.selectedLogoId,
      customLogoBase64: customLogoBase64 ?? this.customLogoBase64,
      logoSize: logoSize ?? this.logoSize,
      showQrCode: showQrCode ?? this.showQrCode,
      showTerms: showTerms ?? this.showTerms,
    );
  }
}
