class AppConfig {
  static const String networkName = "تاج نت 4G";
  static const String serviceNumber = "967784336270";
  static const String registrationSupportNumber = "967784336270";
  static const double minDepositAmount = 500.0; // الحد الأدنى لشحن المحفظة (بالريال)

  // ─── FCM HTTP v1 API - Service Account Credentials ──────────────────────────
  // للحصول على هذه البيانات: Firebase Console → Project Settings → Service accounts → Generate new private key
  static const String fcmProjectId = "tajnetapp";
  static const String fcmClientEmail =
      "firebase-adminsdk-fbsvc@tajnetapp.iam.gserviceaccount.com";
  static const String fcmClientId = "111036184024800416781";
  static const String fcmPrivateKey =
      "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCWWr8NlO3vTbpc\nYFtGRqTW34od2glcUuqcgC8ego9yaO8NAiQJ68+lpLNyXJ/6bHnMm5VazpL+nUQO\nO8v9EwSVsdbOVCsGp/DdRFGiFINfGGe/nAcWt1LLJMOVPBex0HFvbAVgELI1wq1H\nW0A/oTA9AfX/5dv9qpVfZtn9Fz1FqhpxjXvUc/LDvhNJdlbbJdOCT+YgzUajOovP\ndpzxO40GUFKACT5CmGnDAF/+49CKSWcR+HD8eynj8oaAthJ9XRqy7NWCJTniS0Id\nLiFc3GBqD2DPfEJ5E2SR4JdufF9cvBAhF73Jrke7dlrvDfobwOGrtOBGrsFidzxH\niJSz0ZLrAgMBAAECggEADgFA54p2SUKTt9QP3HFrHEqxKkurcIqWqOI1wWFG7FDC\n55LJ+ZSaAGNhhacEDcb552mclVtFjOroMm02eInDdRAeIpTrdxDAmlOpSPAhNoPm\n8g2eCWslDqALicSRrnHshwToUUTs3J4YFtv0lZi1jhE3MVFfVvcDN+I0LuNxxSHJ\nDLPIh7PdK5HHEiuOVxZvKHNM53wfs7TtClraYrs5KNiylPvJ7RTirTCID7iBOO9e\nwZJ8aFz4ye8RQ+SDnkMNtPHiAlsw77Jiw4wXMtRgL+gyyNKC42s+WslubL7qq+kR\nDxAnvLvmnlQ4Ozsgyu5ic2xQjIMXt4fndZ/EmoCpdQKBgQDGLD6jdmzwRxhIMKwI\n7dxYcBkCmYUoRdYui1jiaJG5rNIqEr+YGtHcerXfuMEgSqA8guE3jIxGenBLgc5Q\nFG7EFNHUipEkTfNcz0mKgBWXblPL401KAHcLFJabcHr2yGStBz0i0tHJfnzDVCmr\n7mOU0MpDh3f0u+2oM3pqXbTtxwKBgQDCOmlcMc9dmKRsrfPHaQeL7zMJZ+mGBHX3\nmcvhQin3aW9AqJHuFN7HvQhrgUNL2xKgwj4pvQm9/Ou2epBNBMespmJW3RD6rppY\nbBJ6btZieq28FxfFX+z7Rz37UFVDeR1em74Y1zbvVKegDqmtbtcsBvA7oTlDmPym\n6BNbHi3BvQKBgQCBYjmzN4qAhapQ15Y6bjHCe82YaOsLFC12TfxGNceO1kqQtZTp\nlfkWXfeIjXNpxc9AMqMgRV8AVMgkRCeTGQQIeR9WCPIiJdKR8bQt/Nob+Cg1ob3A\nZvVSAqsh6RofLU6tuWAs8D+Pskl6reRXIFlbu8WSuUuUOW48tv9hmrSZ2QKBgGHQ\novEAUMt1LRFihYvelCNgApbxEwUgR/y7Ipc+B/6GxbWNb3i0YAG9bHkfrzGLkZUO\nXdoNTtO0hUzv6q4vAxQq8wmF6aAlwKtZOfEY0rTjzY0VIC6RgbqGhWuEaHxDiYv0\n6UZ/VDYxrv2HhOJIGOseT2voZPtrF4pDBER2LVsNAoGALPOLDEUHAbiEYeu617W6\n1UtyRVDffGGOk/ILcArNM7sU1e+/cefFfkQ0OxTd97LV4PHWjAL2wTk/VBp3rRiO\nwK+yN8FOLwNSHECP168yFVpzIZ5SE3/B6BDoR9rFxBJNMa1sZT4+suhyLzaH0zOO\nTOil8BAV4jWbM7paXp8Io+o=\n-----END PRIVATE KEY-----\n";

  static const List<Map<String, String>> sellPoints = [
    {"name": "محل تاج الفخامة - السوق"},
    {"name": "بقالة الحرمين - السوق"},
    {"name": "بقالة الاصدقاء - السوق"},
    {"name": "بقالة تموينات البركة - ساحة ال علي الحاج"},
    {"name": "بقالة ثمار للتسوق - ساحة ال علي الحاج"},
    {"name": "بقالة الجهوري - ساحة ال علي الحاج"},
    {"name": "بقالة عوض - حصن ال الزوع"},
    {"name": "بقالة كيلو واحد - حصن ال الزوع"},
    {"name": "معرض البيت السعيد - حصن ال الزوع"},
    {"name": "بقالة عدنان بفلح - حصن ال الزوع"},
    {"name": "بقالة بن وبر - حصن ال الزوع"},
  ];
}
