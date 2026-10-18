# Messenger Lite

Lekki, nieoficjalny klient Messengera dla macOS. Aplikacja wyświetla
`facebook.com/messages` w natywnym oknie opartym na systemowym WebKit, bez
dołączania Chromium lub Electron.

> Projekt niezależny i niepowiązany z Meta ani Facebookiem. Messenger i Facebook
> są znakami towarowymi Meta Platforms, Inc.

## Funkcje

- Natywne okno macOS i ikona aplikacji.
- Zachowywanie sesji logowania w systemowym WebKit.
- Osobne okna otwierane przez stronę, w tym okna rozmów.
- Dostęp do kamery i mikrofonu po udzieleniu uprawnień przez użytkownika.
- Ukrywanie górnej belki Facebooka i panelu szczegółów rozmowy na stronie wiadomości.
- Pobieranie obrazów zamiast zastępowania okna Messengera podglądem obrazu.
- Pobierane pliki trafiają do folderu `Pobrane`; istniejące pliki nie są nadpisywane.
- `Esc` oraz menu `Widok → Zamknij podgląd obrazu` pozwalają wrócić z podglądu.

## Wymagania

- macOS 14 lub nowszy.
- Mac z Apple Silicon (arm64).
- Xcode Command Line Tools, w tym Swift i `iconutil`.
- Połączenie z internetem i konto Facebook/Messenger.

Zainstaluj narzędzia wiersza poleceń, jeśli nie są dostępne:

```sh
xcode-select --install
```

## Budowanie

Sklonuj repozytorium, przejdź do katalogu projektu i uruchom skrypt:

```sh
git clone https://github.com/meehow81-creator/messenger-lite.git
cd messenger-lite
zsh build.sh
```

Gotowa aplikacja pojawi się tutaj:

```text
build/Messenger Lite.app
```

Można ją przenieść do `/Applications` lub `~/Applications`. Skrypt kompiluje
aplikację dla Apple Silicon, generuje ikonę i podpisuje ją lokalnym podpisem
ad hoc. Nie tworzy instalatora ani podpisu deweloperskiego Apple.

## Uprawnienia

macOS poprosi o dostęp do kamery i mikrofonu przy pierwszym użyciu. Dostęp
ograniczony jest do bezpiecznych stron Facebooka i Messengera. W razie odmowy
można zmienić uprawnienia w `Ustawienia systemowe → Prywatność i ochrona`.

W ustawieniach samego połączenia wybierz właściwą kamerę, mikrofon i wyjście
dźwięku. Urządzenia wirtualne, takie jak kamera do udostępniania obrazu, mogą
pokazywać planszę instruktażową zamiast obrazu z kamery Maca.

## Ograniczenia

- Messenger jest serwisem Meta i może zmienić interfejs lub ograniczyć działanie
  w osadzonym WebKit. Aktualizacja aplikacji może być wtedy konieczna.
- Aplikacja identyfikuje osadzony WebKit jako Safari, ale nie jest pełną
  przeglądarką Safari ani Chromium.
- Zgodność rozmów audio i wideo zależy od bieżącej wersji Messengera, macOS,
  dostępnych urządzeń oraz ustawień konta. Nie jest gwarantowana.
- Aplikacja nie jest notaryzowana przez Apple. Przy uruchomieniu pobranej kopii
  macOS może wyświetlić ostrzeżenie Gatekeepera.
- Konto, wiadomości i rozmowy pozostają usługami Meta i podlegają jej warunkom
  oraz polityce prywatności.

## Prywatność

Aplikacja nie zawiera własnego serwera, analityki ani telemetrii. Łączy się
bezpośrednio z witryną Facebooka, aby wyświetlić Messenger. Nie przechowuj
plików sesji ani danych logowania w zgłoszeniach błędów.

## Licencja

W repozytorium nie ma jeszcze pliku licencji. Do czasu jej dodania nie należy
zakładać, że kod jest udostępniony na warunkach licencji open source.
