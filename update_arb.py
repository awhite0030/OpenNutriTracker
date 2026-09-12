import json

def update_arb(file_path, translations):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for key, value in translations.items():
        data[key] = value

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

translations = {
    'intl_en.arb': {
        'emptySearchSubtitle': 'Scan a barcode or create a custom food instead.',
        'emptySearchScanAction': 'Scan a barcode',
        'emptySearchCustomAction': 'Create custom food'
    },
    'intl_de.arb': {
        'emptySearchSubtitle': 'Scannen Sie einen Barcode oder erstellen Sie stattdessen ein eigenes Lebensmittel.',
        'emptySearchScanAction': 'Barcode scannen',
        'emptySearchCustomAction': 'Eigenes Lebensmittel erstellen'
    },
    'intl_cs.arb': {
        'emptySearchSubtitle': 'Naskenujte čárový kód nebo místo toho vytvořte vlastní potravinu.',
        'emptySearchScanAction': 'Naskenovat čárový kód',
        'emptySearchCustomAction': 'Vytvořit vlastní potravinu'
    },
    'intl_it.arb': {
        'emptySearchSubtitle': 'Scansiona un codice a barre o crea invece un alimento personalizzato.',
        'emptySearchScanAction': 'Scansiona codice a barre',
        'emptySearchCustomAction': 'Crea alimento personalizzato'
    },
    'intl_pl.arb': {
        'emptySearchSubtitle': 'Zeskanuj kod kreskowy lub utwórz własny produkt spożywczy.',
        'emptySearchScanAction': 'Zeskanuj kod kreskowy',
        'emptySearchCustomAction': 'Utwórz własny produkt'
    },
    'intl_sk.arb': {
        'emptySearchSubtitle': 'Naskenujte čiarový kód alebo namiesto toho vytvorte vlastnú potravinu.',
        'emptySearchScanAction': 'Naskenovať čiarový kód',
        'emptySearchCustomAction': 'Vytvoriť vlastnú potravinu'
    },
    'intl_tr.arb': {
        'emptySearchSubtitle': 'Bunun yerine bir barkod tarayın veya özel bir yiyecek oluşturun.',
        'emptySearchScanAction': 'Barkod tara',
        'emptySearchCustomAction': 'Özel yiyecek oluştur'
    },
    'intl_uk.arb': {
        'emptySearchSubtitle': 'Замість цього відскануйте штрих-код або створіть власну їжу.',
        'emptySearchScanAction': 'Сканувати штрих-код',
        'emptySearchCustomAction': 'Створити власну їжу'
    },
    'intl_zh.arb': {
        'emptySearchSubtitle': '扫描条形码或创建一个自定义食物。',
        'emptySearchScanAction': '扫描条形码',
        'emptySearchCustomAction': '创建自定义食物'
    }
}

for file_name, trans in translations.items():
    update_arb(f'lib/l10n/{file_name}', trans)

print("Updated arb files.")
