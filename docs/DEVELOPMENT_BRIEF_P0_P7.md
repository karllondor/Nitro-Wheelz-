# NITRO WHEELZ — Development Brief P0–P7

**Źródło:** szczegółowy brief użytkownika z 18 listopada 2026. To nadrzędna lista wymagań produkcyjnych i kryteriów akceptacji; implementacja kodu nie oznacza automatycznie zaliczonego testu na telefonie.

**Priorytet:** rozgrywka, geometria, kolizje, kamera i scoring przed dalszym polerowaniem grafiki. Referencja responsywności: DRIFTIT (bez kopiowania jego kodu lub materiałów).

## P0 — Geometria i kolizje: krytyczne

- Jedna ciągła zamknięta krzywa centralna; z niej wyznaczać nawierzchnię, białe linie, pobocza, barykady i odpowiadające im collidery.
- Żadnych samoprzecięć, podwójnych punktów, losowych trójkątów, ostrych przypadkowych załamań ani zdublowanych barier.
- Zaprojektowane techniczne zakręty i kontrolowane poszerzenia; brak niezamierzonych skrótów.
- Kolizja w pozycji widocznej bariery: wytracenie prędkości, łagodne odbicie, bez przenikania/przyklejania.
- Start/meta prostopadłe do osi drogi i w prawidłowym miejscu; kierunek startowy do góry na ekranie.
- Warunek: pełne trzy okrążenia bez błędów toru po rzeczywistej próbie na telefonie.

## P1 — Dynamiczna kamera

- Przyspieszanie = płynne oddalanie, hamowanie = płynne przybliżanie.
- Początkowa równoważna skala Camera2D: 0–20 km/h 1.15; 40–60 km/h 1.00; 80–100 km/h 0.82; powyżej 120 km/h 0.72. Dla Camera3D regulować orthographic size lub FOV/wysokość.
- Lead 0.4–0.5 s według **rzeczywistego wektora prędkości**, nie samego przodu samochodu, z ograniczeniem odległości.
- Bez obracania świata w top-down; samochód użytecznie poniżej centrum i widoczne wyjście z zakrętu.
- Chase: odpowiedni pitch i wysokość, mało pustego nieba, unikać zasłaniania przez bariery i drzewa.

## P2 — Prowadzenie i drift

- Minimalna zwłoka joysticka, szybkość i powrót kierownicy zależne od prędkości.
- Ręczny natychmiast zrywa przyczepność tyłu; utrzymanie driftu wymaga gazu i kontry, nie automatycznego obracania.
- Płynne lewo–prawo, brak niekontrolowanych spinów, naturalne hamowanie.
- Kolizje testować pod wieloma kątami i prędkościami.
- Rozdzielić symulację fizyczną i rotację modelu graficznego; subtelna, wyłączalna wibracja telefonu.
- **OBOWIĄZKOWO przetestować prowadzenie na fizycznym Androidzie.**

## P3 — Nitro drift scoring: LINE + ZONES + ANGLE + COMBO

- Bez maksymalnego limitu. Punkty naliczane ciągle podczas kontrolowanego driftu: zależne od prędkości, kąta i czasu.
- Dłuższy drift zwiększa combo; krótka zmiana strony driftu nie musi zrywać mnożnika.
- Bonus za prawidłową linię i wypełnione strefy. Jazda środkiem nadal punktuje, ale mniej.
- Outside Zone sprawdza **tył samochodu**. Inside Clip sprawdza **przód**.
- Idealna linia nie leży na murze. Początkowo odstęp 0.8–1.5 m między najbliższym elementem karoserii a barierą.
- Dokładność oceniać gładką funkcją; dodatkowy bonus za zaliczenie całej strefy, **raz na okrążenie**.
- Uderzenie w mur, spin lub utrata kontroli karze i przerywa aktywne combo.
- Brak punktów za kręcenie się w miejscu. Widoczne oznaczenia stref, opcjonalna linia prowadząca tylko w treningu.

## P4 — Laps, scores, progression

- Circuit Drift: zamknięty tor i domyślnie 3 okrążenia; suma punktów decyduje o końcowej ocenie.
- Combo może przejść przez metę. Czas jest statystyką, **nie kryterium awansu**.
- Gwiazdki i odblokowania z punktów; ranking globalny według punktów przy porównywalnej liczbie okrążeń.
- Uporządkowane checkpointy i właściwy kierunek przekraczania mety, bez skrótów ani nabijania okrążeń wstecz.
- Osobny Drift Competition jest pomysłem na przyszłość, nie na tę iterację.

## P5 — Docelowy mobilny HUD

- Zatwierdzony design Nitro Wheelz zamiast aktualnego prototypu.
- Jeden pasek statystyk przy górnej krawędzi; wynik i combo czytelne, CAM i PAUSE bezpośrednio poniżej.
- Kąt driftu tylko liczbowo; kompaktowy speedometer.
- Pionowy, prosty ręczny przy prawej krawędzi z przyciskiem u podstawy.
- Metalowe pedały GAS/BRAKE, joystick lewy dolny.
- Czytelny aktywny bonus za strefę. UI nie może zasłaniać wyjścia z zakrętu; touch hitboxy duże nawet przy mniejszej grafice.

## P6 — Czytelność wizualna i assety

- Bezszwowe tekstury asfaltu, zróżnicowane pobocza i otoczenie.
- Biało-niebieskie bandy ciągłe i estetyczne.
- Ślady dokładnie w miejscu kontaktu opon, stopniowe wygaszanie, subtelniejszy odcień.
- Dym tylnych opon na podstawie intensywności poślizgu.
- Drzewa, lampy i rekwizyty nie mogą przenikać asfaltu ani zasłaniać drogi.

## P7 — Akceptacja i wydania

- 3 pełne okrążenia **przejechane na Androidzie**, bez wizualnych/geometr. artefaktów.
- Testy uderzeń zewnętrznych i wewnętrznych ścian pod kilkoma kątami i prędkościami.
- Zoom w trakcie przyspieszania i hamowania, widoczność wyjścia z długiego zakrętu.
- Lewo/prawo drift z combo; Inside Clip, Outside Zone, zerowy drift-score na postoju.
- Rozliczenie stref, punktów i combo po każdym okrążeniu, obie kamery.
- Fizyczny multitouch gas+joystick+handbrake, FPS, render i stabilność telefonu.
- Każde wydanie: Web, Android APK, desktop, źródła, CHANGELOG oraz QA.
- **Nie twierdzić, że fizyczny błąd naprawiono wyłącznie na podstawie zmiany kodu lub CI PASS.**

## Aktualny zakres realizacji

- **v0.1.5 P0**: kompilator zamkniętej krzywej, edytowalne dane Track DNA i walidator geometrii oraz wspólne krawędzie/kolizje: Godot CI PASS. Rzeczywiste 3 okrążenia NOT RUN.
- **v0.1.6 P1**: dynamiczny zoom/lead i testy numeryczne PASS; camera/chase na telefonie NOT RUN.
- **P2–P7**: wymagania zaakceptowane jako roadmap, bez deklaracji realizacji.
