# FabriX

FabriX turns Farming Simulator productions into a staffing and operations business: factories need employees in shifts, employees gain experience and advance, factories are upgraded over time.

Terms are listed as **English** (Deutsch). The English term is canonical in code comments, docs and `l10n_en.xml`; the German term is canonical in `l10n_de.xml`.

## Employees

**Employee** (Mitarbeiter):
Any person hired by a farm through FabriX, regardless of category.
_Avoid_: Worker, helper (in player-facing text)

**Category** (Kategorie):
One of three employee types: Seasonal Worker, Apprentice or Skilled Worker.

**Seasonal Worker** (Erntehelfer):
An employee usable in any shift right away, levelling from 1 to 10 without a career path.
_Avoid_: Harvest helper, helper

**Apprentice** (Azubi):
An employee on level 1–3 of the career path who is still in training and cannot be dismissed.
_Avoid_: Trainee, intern

**Skilled Worker** (Facharbeiter):
An employee on level 4–10 of the career path; holds one of the Roles Journeyman, Master or Director.
_Avoid_: Specialist, professional

**Career path** (Laufbahn):
The level sequence Apprentice → Journeyman → Master → Director.

**Role** (Rolle):
The title a Skilled Worker holds by level: Journeyman (4–6), Master (7–9), Director (10).

**Journeyman** (Geselle):
A Skilled Worker who has finished the apprenticeship (level 4–6).

**Master** (Meister):
A Skilled Worker holding a master craftsman qualification (level 7–9); required to fill a Master slot.
_Avoid_: Foreman, master craftsman (in short labels)

**Director** (Betriebsleiter):
A Skilled Worker at the top level (10); required to fill a Director slot.
_Avoid_: Plant manager, factory manager

**Training** (Fortbildung):
A period of several months after which an employee advances on the career path; automatic for Apprentices, paid and started by the player before Master and Director.
_Avoid_: School, Weiterbildung, Schule

**Job market** (Arbeitsmarkt):
The pool of applicants a farm can hire from.

**Notice period** (Kündigungsfrist):
Months between dismissing an employee and the employee leaving.

**Severance** (Abfindung):
A one-time payment owed when an employee leaves through dismissal or failed apprenticeship.

## Factories

**Factory** (Fabrik):
A production placeable that FabriX staffs and upgrades.
_Avoid_: Production, plant

**Factory level** (Fabriklevel):
A factory's upgrade stage (1–5); determines slots per shift, storage and required leadership.

**Upgrade** (Ausbau):
Buying the next Factory level once the factory has enough experience.

**Renovation** (Renovierung):
The period after an Upgrade during which the factory does not produce.

**Shift** (Schicht):
One of three 8-hour blocks per day: Early (Früh-), Day (Tag-), Late (Spätschicht).

**Slot** (Platz):
A position in a shift that one employee can fill.

**Leadership slot** (Führungsrolle):
A Master or Director position in a factory, outside the shift slots.

## Progression

**Experience / XP** (Erfahrung):
Points employees and factories earn while a factory produces.

**Level**:
An employee's or factory's progression stage, gained through XP.
