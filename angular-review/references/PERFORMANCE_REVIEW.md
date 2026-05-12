---
name: angular-performance-reviewer
description: Audit performance Angular (lazy routes, @defer, NgOptimizedImage, SSR, OnPush, zoneless, profiling, zone pollution, slow computations).
domain: performance
rule_prefix: R-PERF
applies_to:
  - "**/*.ts"
  - "**/*.html"
  - "src/**/app.routes*.ts"
  - "src/**/app.config*.ts"
  - "angular.json"
severity_levels: [BLOCKER, MAJOR, MINOR, INFO]
output_format: json
parallel_safe: true
sources:
  - https://angular.dev/best-practices/performance
  - https://angular.dev/best-practices/runtime-performance
  - https://angular.dev/guide/zoneless
---

# Reviewer Guideline — Performance Angular

## But

Ce document fournit à un agent reviewer LLM les règles actionnables pour auditer les changements de code Angular sous l'angle **performance** (chargement, runtime, change detection, SSR, zoneless). Chaque règle est accompagnée d'un pattern à détecter, d'un exemple à rejeter et d'un exemple à approuver. Le reviewer doit produire des findings structurés conformes à la section finale.

## Niveaux de sévérité

- 🔴 **BLOCKER** — bug fonctionnel, régression de perf majeure, mismatch d'hydratation, fuite mémoire, anti-pattern documenté comme proscrit.
- 🟠 **MAJOR** — perte de performance significative ou non-respect d'une best-practice officielle ; à corriger avant merge.
- 🟡 **MINOR** — amélioration recommandée par la doc Angular ; à corriger si possible.
- 🔵 **INFO** — suggestion ou rappel pédagogique, non bloquant.

---

## Règles à vérifier

### R-PERF-001 — Routes lazy via `loadComponent` / `loadChildren`

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : toute route secondaire (non landing) doit utiliser `loadComponent` ou `loadChildren` plutôt que `component:` direct.
- **Pattern à flag** : objet `Route` avec `component: XxxComponent` import statique ailleurs que sur la route racine `path: ''`.
- **Exemple ❌** :
  ```ts
  import { LoginPage } from './components/auth/login-page';
  export const routes: Routes = [
    { path: 'login', component: LoginPage },
  ];
  ```
- **Exemple ✅** :
  ```ts
  export const routes: Routes = [
    { path: '', component: HomePage },
    { path: 'login', loadComponent: () => import('./components/auth/login-page') },
  ];
  ```
- **Source** : <https://angular.dev/best-practices/performance/lazy-loaded-routes>

### R-PERF-002 — `export default` dans les modules lazy

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : un fichier ciblé par `loadComponent` doit utiliser `export default` pour permettre la forme courte `() => import('./x')`.
- **Pattern à flag** : `loadComponent: () => import('./x').then(m => m.XComponent)` alors que le fichier pourrait `export default`.
- **Exemple ❌** :
  ```ts
  // login-page.ts
  export class LoginPage {}
  // routes
  loadComponent: () => import('./login-page').then(m => m.LoginPage);
  ```
- **Exemple ✅** :
  ```ts
  // login-page.ts
  export default class LoginPage {}
  // routes
  loadComponent: () => import('./login-page');
  ```
- **Source** : <https://angular.dev/best-practices/performance/lazy-loaded-routes>

### R-PERF-003 — Pas de cascade excessive de lazy-loading

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : éviter les chaînes `loadChildren` → `loadChildren` → `loadComponent` qui multiplient les round-trips.
- **Pattern à flag** : profondeur > 2 de routes lazy pour une même navigation utilisateur fréquente.
- **Exemple ❌** :
  ```ts
  // 3 niveaux de lazy chained pour atteindre une page courante
  { path: 'a', loadChildren: () => import('./a').then(m => m.A_ROUTES) }
  // dans A_ROUTES → loadChildren → loadComponent
  ```
- **Exemple ✅** :
  ```ts
  // Aplatir : un seul niveau lazy pour un parcours fréquent
  { path: 'a/b', loadComponent: () => import('./a/b/page') }
  ```
- **Source** : <https://angular.dev/best-practices/performance/lazy-loaded-routes>

### R-PERF-004 — Dépendance `@defer` doit être standalone

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : un composant/directive/pipe utilisé dans un `@defer` doit être `standalone: true`. Sinon il reste eager.
- **Pattern à flag** : composant non standalone (déclaré dans `NgModule.declarations`) référencé à l'intérieur d'un bloc `@defer`.
- **Exemple ❌** :
  ```ts
  @Component({ selector: 'large', template: '...' }) // pas de standalone:true
  export class LargeComponent {}
  ```
  ```html
  @defer { <large /> }
  ```
- **Exemple ✅** :
  ```ts
  @Component({ standalone: true, selector: 'large', template: '...' })
  export class LargeComponent {}
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-005 — Pas de référence à la dépendance `@defer` hors du bloc

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : la dépendance ne doit jamais être utilisée hors du bloc `@defer` (template direct, `@ViewChild`, autre `@defer`). Sinon elle est chargée eagerly.
- **Pattern à flag** : sélecteur `<x />` ou `viewChild(XComponent)` présent dans le même template/composant que `@defer { <x /> }`.
- **Exemple ❌** :
  ```html
  <large-component #ref />
  @defer { <large-component /> }
  ```
- **Exemple ✅** :
  ```html
  @defer { <large-component /> }
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-006 — `@defer` interdit pour le contenu above-the-fold

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : ne pas `@defer` du contenu visible au premier rendu (augmente le CLS, dégrade le LCP). Triggers `immediate`, `timer(0)`, `viewport` sur élément déjà visible, `when` truthy au boot sont à éviter.
- **Pattern à flag** : `@defer (on immediate)` ou `@defer (on viewport)` sur un bloc placé au début du template d'une page principale.
- **Exemple ❌** :
  ```html
  @defer (on immediate) { <hero-banner /> }
  ```
- **Exemple ✅** :
  ```html
  <hero-banner />
  @defer (on viewport) { <below-fold-section /> }
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-007 — `@defer` imbriqués doivent avoir des triggers différents

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : éviter la cascade de chargements ; un `@defer` enfant avec le même trigger que le parent crée un effet domino.
- **Pattern à flag** : deux `@defer` imbriqués déclenchés par le même trigger (ex. `viewport` puis `viewport`).
- **Exemple ❌** :
  ```html
  @defer (on viewport) {
    <component-a />
    @defer (on viewport) { <component-b /> }
  }
  ```
- **Exemple ✅** :
  ```html
  @defer (on viewport) {
    <component-a />
    @defer (on hover) { <component-b /> }
  }
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-008 — `@placeholder` avec `minimum` pour éviter le flicker

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : si un `@placeholder` est utilisé avec une dépendance qui peut arriver très vite, ajouter `minimum`.
- **Pattern à flag** : `@placeholder { ... }` sans option `minimum` pour un chunk de petite taille.
- **Exemple ❌** :
  ```html
  @defer { <x /> }
  @placeholder { <p>Loading…</p> }
  ```
- **Exemple ✅** :
  ```html
  @defer { <x /> }
  @placeholder (minimum 500ms) { <p>Loading…</p> }
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-009 — `@defer` annoncé via région ARIA live

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : un bloc `@defer` doit être enveloppé dans un container `aria-live` pour l'accessibilité.
- **Pattern à flag** : `@defer` au niveau racine d'un template sans wrapper `aria-live`.
- **Exemple ❌** :
  ```html
  @defer (on timer(2s)) { <user-profile /> }
  ```
- **Exemple ✅** :
  ```html
  <div aria-live="polite" aria-atomic="true">
    @defer (on timer(2s)) { <user-profile /> }
  </div>
  ```
- **Source** : <https://angular.dev/best-practices/performance/defer>

### R-PERF-010 — Utiliser `ngSrc` (pas `src`) avec `NgOptimizedImage`

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : tout `<img>` ciblé par les optimisations doit utiliser l'attribut `ngSrc`. Conserver `src` annule les optimisations (le navigateur télécharge avant).
- **Pattern à flag** : `<img src="...">` dans un composant qui importe `NgOptimizedImage`, ou présence simultanée de `src` et `ngSrc`.
- **Exemple ❌** :
  ```html
  <img src="cat.jpg" width="400" height="200" />
  ```
- **Exemple ✅** :
  ```html
  <img ngSrc="cat.jpg" width="400" height="200" />
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-011 — `priority` sur l'image LCP

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : l'image LCP (above-the-fold, hero, premier visuel) doit porter `priority`.
- **Pattern à flag** : premier `<img ngSrc>` du template d'une page d'entrée sans attribut `priority`.
- **Exemple ❌** :
  ```html
  <img ngSrc="hero.jpg" width="1200" height="600" />
  ```
- **Exemple ✅** :
  ```html
  <img ngSrc="hero.jpg" width="1200" height="600" priority />
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-012 — `width` et `height` obligatoires (sauf `fill`)

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : tout `<img ngSrc>` doit avoir `width` et `height` explicites pour éviter le CLS, sauf en mode `fill`.
- **Pattern à flag** : `<img ngSrc="...">` sans `width` ni `height` ni `fill`.
- **Exemple ❌** :
  ```html
  <img ngSrc="cat.jpg" />
  ```
- **Exemple ✅** :
  ```html
  <img ngSrc="cat.jpg" width="400" height="200" />
  <!-- ou -->
  <img ngSrc="cat.jpg" fill />
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-013 — `fill` requiert un parent positionné

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : un `<img ngSrc fill>` doit avoir un parent `position: relative | fixed | absolute`.
- **Pattern à flag** : `<img ngSrc ... fill>` dont le parent direct n'a pas de positionnement non-static.
- **Exemple ❌** :
  ```html
  <div>
    <img ngSrc="bg.jpg" fill />
  </div>
  ```
- **Exemple ✅** :
  ```html
  <div style="position: relative">
    <img ngSrc="bg.jpg" fill />
  </div>
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-014 — `sizes` pour les images responsive

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : pour une image dont la taille rendue dépend du viewport, fournir `sizes` afin qu'Angular génère le bon `srcset`.
- **Pattern à flag** : `<img ngSrc>` dans un layout responsive sans attribut `sizes`.
- **Exemple ❌** :
  ```html
  <img ngSrc="cat.jpg" width="400" height="200" />
  ```
- **Exemple ✅** :
  ```html
  <img ngSrc="cat.jpg" width="400" height="200"
       sizes="(max-width: 768px) 100vw, 50vw" />
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-015 — Configurer un `IMAGE_LOADER` (CDN)

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : si l'app sert des images depuis un CDN, fournir un `IMAGE_LOADER` ou un loader prêt (`provideImgixLoader`, etc.).
- **Pattern à flag** : URLs absolues vers un CDN sans `IMAGE_LOADER` configuré dans `app.config.ts`.
- **Exemple ❌** :
  ```ts
  // pas de provider IMAGE_LOADER
  bootstrapApplication(App, { providers: [] });
  ```
- **Exemple ✅** :
  ```ts
  providers: [{
    provide: IMAGE_LOADER,
    useValue: (cfg: ImageLoaderConfig) =>
      `https://cdn.example.com/${cfg.src}?w=${cfg.width}`
  }]
  ```
- **Source** : <https://angular.dev/best-practices/performance/image-optimization>

### R-PERF-016 — Code browser-only via `afterNextRender` (pas `isPlatformBrowser`)

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : en SSR, le code accédant à `window`, `document` ou aux dimensions DOM doit être placé dans `afterNextRender` / `afterRender`. `isPlatformBrowser()` dans le template provoque des mismatchs d'hydratation.
- **Pattern à flag** : `if (isPlatformBrowser(...))` autour d'un accès DOM dans `ngOnInit` ou dans un template (`@if (isBrowser) { ... }`).
- **Exemple ❌** :
  ```ts
  ngOnInit() {
    if (isPlatformBrowser(this.platformId)) {
      console.log(this.el.nativeElement.scrollHeight);
    }
  }
  ```
- **Exemple ✅** :
  ```ts
  constructor() {
    afterNextRender(() => {
      console.log(this.el.nativeElement.scrollHeight);
    });
  }
  ```
- **Source** : <https://angular.dev/best-practices/performance/ssr>

### R-PERF-017 — Injecter `DOCUMENT`, pas `document` global

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : tout accès au document doit passer par `inject(DOCUMENT)`. La référence globale `document` n'existe pas côté serveur.
- **Pattern à flag** : usage de `document.xxx` ou `window.document` dans un service/composant Angular.
- **Exemple ❌** :
  ```ts
  const el = document.getElementById('app');
  ```
- **Exemple ✅** :
  ```ts
  private readonly doc = inject(DOCUMENT);
  const el = this.doc.getElementById('app');
  ```
- **Source** : <https://angular.dev/best-practices/performance/ssr>

### R-PERF-018 — `inject()` synchrone (pas après un `await`)

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : `inject()` doit être appelé synchroniquement dans le contexte d'injection (ex. `getPrerenderParams`, factories). Jamais après un `await`.
- **Pattern à flag** : `await ...` suivi d'un `inject(...)` dans la même fonction.
- **Exemple ❌** :
  ```ts
  async getPrerenderParams() {
    const ids = await fetch('/api/ids').then(r => r.json());
    const svc = inject(MyService); // KO
    return ids.map(id => ({ id }));
  }
  ```
- **Exemple ✅** :
  ```ts
  async getPrerenderParams() {
    const svc = inject(MyService); // OK : sync
    const ids = await svc.getIds();
    return ids.map(id => ({ id }));
  }
  ```
- **Source** : <https://angular.dev/best-practices/performance/ssr>

### R-PERF-019 — `transferCache` configuré pour SSR + ne pas cacher l'auth

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : avec SSR + hydratation, configurer `withHttpTransferCacheOptions` ; ne **pas** activer `includeRequestsWithAuthHeaders: true` sans précaution ; filtrer les routes sensibles.
- **Pattern à flag** : `provideClientHydration()` sans options de cache OU `includeRequestsWithAuthHeaders: true` non justifié.
- **Exemple ❌** :
  ```ts
  provideClientHydration(
    withHttpTransferCacheOptions({ includeRequestsWithAuthHeaders: true })
  );
  ```
- **Exemple ✅** :
  ```ts
  provideClientHydration(
    withHttpTransferCacheOptions({
      includeHeaders: ['ETag'],
      filter: req => !req.url.includes('/api/profile'),
      includeRequestsWithAuthHeaders: false,
    })
  );
  ```
- **Source** : <https://angular.dev/best-practices/performance/ssr>

### R-PERF-020 — `ChangeDetectionStrategy.OnPush` sur les composants

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : tout composant non trivial doit déclarer `changeDetection: ChangeDetectionStrategy.OnPush`. Indispensable pour préparer la migration zoneless.
- **Pattern à flag** : `@Component({...})` sans `changeDetection`, ou `Default` explicite.
- **Exemple ❌** :
  ```ts
  @Component({ selector: 'x', template: '...' })
  export class X {}
  ```
- **Exemple ✅** :
  ```ts
  @Component({
    selector: 'x',
    template: '...',
    changeDetection: ChangeDetectionStrategy.OnPush,
  })
  export class X {}
  ```
- **Source** : <https://angular.dev/best-practices/skipping-subtrees>

### R-PERF-021 — Mutations d'`@Input` : nouvelle référence (pas mutation in-place)

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : avec `OnPush`, muter un objet/tableau `@Input` sans nouvelle référence n'invalide pas le sous-arbre.
- **Pattern à flag** : `this.items.push(...)`, `this.config.foo = ...`, `Object.assign(this.input, ...)` côté parent transmis à un enfant `OnPush`.
- **Exemple ❌** :
  ```ts
  this.items.push(newItem);
  this.user.name = 'Alice';
  ```
- **Exemple ✅** :
  ```ts
  this.items = [...this.items, newItem];
  this.user = { ...this.user, name: 'Alice' };
  ```
- **Source** : <https://angular.dev/best-practices/skipping-subtrees>

### R-PERF-022 — `markForCheck()` après modification programmatique d'`@Input`

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : si un parent modifie un input d'enfant via `@ViewChild` / `@ContentChild`, il doit appeler `markForCheck()` (côté enfant) pour notifier la CD.
- **Pattern à flag** : `viewChild.set(...)` ou `viewChild.input = ...` sans `markForCheck` consécutif.
- **Exemple ❌** :
  ```ts
  @ViewChild(ChildCmp) child!: ChildCmp;
  ngAfterViewInit() {
    this.child.value = 42;
  }
  ```
- **Exemple ✅** :
  ```ts
  // Dans ChildCmp
  private cdr = inject(ChangeDetectorRef);
  set value(v: number) { this._v = v; this.cdr.markForCheck(); }
  ```
- **Source** : <https://angular.dev/best-practices/skipping-subtrees>

### R-PERF-023 — Mode zoneless : `provideZonelessChangeDetection` + suppression de `zone.js`

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : si `provideZonelessChangeDetection()` est utilisé, `zone.js` doit être retiré de `polyfills` (`angular.json`) et de `polyfills.ts`.
- **Pattern à flag** : présence de `import 'zone.js'` ou de `"zone.js"` dans `polyfills` alors que zoneless est activé.
- **Exemple ❌** :
  ```ts
  // polyfills.ts
  import 'zone.js';
  // app.config.ts
  providers: [provideZonelessChangeDetection()]
  ```
- **Exemple ✅** :
  ```ts
  // polyfills.ts vide ou sans zone.js
  // app.config.ts
  providers: [provideZonelessChangeDetection()]
  ```
- **Source** : <https://angular.dev/guide/zoneless>

### R-PERF-024 — APIs de stabilité de `NgZone` proscrites en zoneless

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : `NgZone.onStable`, `onUnstable`, `onMicrotaskEmpty`, `isStable` ne sont pas valides en zoneless.
- **Pattern à flag** : `ngZone.onStable.subscribe`, `ngZone.isStable`, `ngZone.onMicrotaskEmpty`.
- **Exemple ❌** :
  ```ts
  this.ngZone.onStable.subscribe(() => this.measure());
  ```
- **Exemple ✅** :
  ```ts
  afterNextRender(() => this.measure());
  // ou MutationObserver pour des changements DOM
  ```
- **Source** : <https://angular.dev/guide/zoneless>

### R-PERF-025 — Reactive Forms en zoneless : `markForCheck` sur `valueChanges`

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : en zoneless, `valueChanges`/`statusChanges` ne déclenchent pas la CD ; appeler `markForCheck()` ou migrer vers signaux.
- **Pattern à flag** : composant `OnPush` zoneless avec `form.valueChanges.subscribe(...)` sans `markForCheck`.
- **Exemple ❌** :
  ```ts
  this.form.valueChanges.subscribe(v => this.computed = compute(v));
  ```
- **Exemple ✅** :
  ```ts
  this.form.valueChanges.pipe(
    tap(() => this.cdr.markForCheck())
  ).subscribe(v => this.computed = compute(v));
  ```
- **Source** : <https://angular.dev/guide/zoneless>

### R-PERF-026 — `PendingTasks` pour le travail asynchrone en SSR zoneless

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : en SSR zoneless, tout travail asynchrone qui doit s'achever avant la sérialisation HTML doit être enregistré via `PendingTasks.run`.
- **Pattern à flag** : `await fetch(...)` dans `ngOnInit` SSR sans `PendingTasks`.
- **Exemple ❌** :
  ```ts
  async ngOnInit() {
    const r = await fetch('/api/data');
    this.state.set(await r.json());
  }
  ```
- **Exemple ✅** :
  ```ts
  private pending = inject(PendingTasks);
  ngOnInit() {
    this.pending.run(async () => {
      const r = await fetch('/api/data');
      this.state.set(await r.json());
    });
  }
  ```
- **Source** : <https://angular.dev/guide/zoneless>

### R-PERF-027 — Pure pipe pour les calculs lents dans le template

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : les calculs coûteux invoqués depuis le template doivent passer par un pure pipe (cache par référence d'inputs) ou un `computed` signal. Pas d'appel de méthode coûteuse depuis le template.
- **Pattern à flag** : `{{ heavyCompute(item) }}` ou `*ngFor="let x of slowSort()"` dans un template.
- **Exemple ❌** :
  ```html
  <p>{{ expensiveCalc(value) }}</p>
  ```
- **Exemple ✅** :
  ```html
  <p>{{ value | expensiveCalc }}</p>
  ```
  ```ts
  @Pipe({ name: 'expensiveCalc', pure: true, standalone: true })
  export class ExpensiveCalcPipe implements PipeTransform { /* ... */ }
  ```
- **Source** : <https://angular.dev/best-practices/slow-computations>

### R-PERF-028 — Pas de lecture/écriture layout dans `ngDoCheck` / `ngAfterViewChecked`

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : ne jamais lire ou écrire des propriétés qui forcent reflow (`offsetWidth`, `getBoundingClientRect`, `scrollTop`, etc.) dans des hooks appelés à chaque tick.
- **Pattern à flag** : accès à `offsetXxx`, `client*`, `scroll*`, `getBoundingClientRect`, `style.xxx =` dans `ngDoCheck` ou `ngAfterViewChecked`.
- **Exemple ❌** :
  ```ts
  ngAfterViewChecked() {
    this.height = this.el.nativeElement.offsetHeight;
  }
  ```
- **Exemple ✅** :
  ```ts
  constructor() {
    afterNextRender(() => {
      this.height = this.el.nativeElement.offsetHeight;
    });
  }
  ```
- **Source** : <https://angular.dev/best-practices/slow-computations>

### R-PERF-029 — Libs tierces et timers dans `runOutsideAngular`

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : `setInterval`, `setTimeout` répétitifs, `requestAnimationFrame`, init de libs (Plotly, Chart.js, Leaflet, Monaco, etc.) doivent s'exécuter via `ngZone.runOutsideAngular`.
- **Pattern à flag** : `setInterval`, `setTimeout`, `requestAnimationFrame`, `new Plotly/Chart/...` au top-level d'un composant sans `runOutsideAngular`.
- **Exemple ❌** :
  ```ts
  ngOnInit() {
    setInterval(() => this.poll(), 500);
  }
  ```
- **Exemple ✅** :
  ```ts
  private ngZone = inject(NgZone);
  ngOnInit() {
    this.ngZone.runOutsideAngular(() =>
      setInterval(() => this.poll(), 500)
    );
  }
  ```
- **Source** : <https://angular.dev/best-practices/zone-pollution>

### R-PERF-030 — Re-rentrer dans la zone (`ngZone.run`) pour les MAJ de vue

- **Sévérité** : 🟠 MAJOR
- **Quoi vérifier** : un callback hors zone qui modifie l'état affiché doit être rentré via `ngZone.run` pour déclencher la CD.
- **Pattern à flag** : `runOutsideAngular` dont le callback met à jour des propriétés liées au template sans `ngZone.run`.
- **Exemple ❌** :
  ```ts
  this.ngZone.runOutsideAngular(() => {
    plot.on('click', e => this.selected = e); // pas de tick
  });
  ```
- **Exemple ✅** :
  ```ts
  this.ngZone.runOutsideAngular(() => {
    plot.on('click', e => this.ngZone.run(() => this.selected = e));
  });
  ```
- **Source** : <https://angular.dev/best-practices/zone-pollution>

### R-PERF-031 — Pas de mutation d'état pendant la CD

- **Sévérité** : 🔴 BLOCKER
- **Quoi vérifier** : ne jamais modifier l'état dans `ngDoCheck`, getters/méthodes appelées par le template, ou `ngAfterViewChecked`. Le profiler montre alors plusieurs passes de synchronisation par cycle.
- **Pattern à flag** : assignation `this.xxx = ...` dans un getter de template, dans `ngDoCheck`, ou dans une méthode `{{ method() }}`.
- **Exemple ❌** :
  ```ts
  get displayValue() {
    this.counter++; // mutation pendant la CD
    return this._value;
  }
  ```
- **Exemple ✅** :
  ```ts
  // Pré-calculer en amont, ou utiliser un computed signal
  protected displayValue = computed(() => this._value());
  ```
- **Source** : <https://angular.dev/best-practices/profiling-with-chrome-devtools>

### R-PERF-032 — Profiling activé en dev (`enableProfiling`)

- **Sévérité** : 🔵 INFO
- **Quoi vérifier** : pour diagnostiquer les régressions, activer `enableProfiling()` avant `bootstrapApplication` en dev (jamais en prod, no-op de toute façon).
- **Pattern à flag** : absence de `enableProfiling()` dans une PR qui ajoute des composants lourds, ou présence en build prod.
- **Exemple ❌** :
  ```ts
  // dev : aucun profiling activé
  bootstrapApplication(App);
  ```
- **Exemple ✅** :
  ```ts
  if (!environment.production) {
    enableProfiling();
  }
  bootstrapApplication(App);
  ```
- **Source** : <https://angular.dev/best-practices/profiling-with-chrome-devtools>

### R-PERF-033 — `[class.x]` / `[style.x]` plutôt que `[ngClass]` / `[ngStyle]`

- **Sévérité** : 🟡 MINOR
- **Quoi vérifier** : préférer les bindings de classe/style natifs aux directives `ngClass`/`ngStyle` (plus simples, plus performants).
- **Pattern à flag** : `[ngClass]="{...}"` ou `[ngStyle]="{...}"` avec un nombre fixe de classes/styles.
- **Exemple ❌** :
  ```html
  <div [ngClass]="{ admin: isAdmin, active: isActive }"></div>
  ```
- **Exemple ✅** :
  ```html
  <div [class.admin]="isAdmin" [class.active]="isActive"></div>
  ```
- **Source** : <https://angular.dev/style-guide>

---

## Checklist finale

- [ ] R-PERF-001 — Routes lazy
- [ ] R-PERF-002 — `export default` lazy
- [ ] R-PERF-003 — Pas de cascade lazy
- [ ] R-PERF-004 — Dépendance `@defer` standalone
- [ ] R-PERF-005 — Pas de référence hors `@defer`
- [ ] R-PERF-006 — Pas de `@defer` above-the-fold
- [ ] R-PERF-007 — Triggers différents pour `@defer` imbriqués
- [ ] R-PERF-008 — `@placeholder (minimum ...)`
- [ ] R-PERF-009 — `aria-live` autour de `@defer`
- [ ] R-PERF-010 — `ngSrc` (pas `src`)
- [ ] R-PERF-011 — `priority` sur LCP
- [ ] R-PERF-012 — `width` / `height` ou `fill`
- [ ] R-PERF-013 — Parent positionné pour `fill`
- [ ] R-PERF-014 — `sizes` responsive
- [ ] R-PERF-015 — `IMAGE_LOADER` configuré
- [ ] R-PERF-016 — `afterNextRender` au lieu de `isPlatformBrowser`
- [ ] R-PERF-017 — `inject(DOCUMENT)`
- [ ] R-PERF-018 — `inject()` synchrone
- [ ] R-PERF-019 — `transferCache` sans auth headers
- [ ] R-PERF-020 — `ChangeDetectionStrategy.OnPush`
- [ ] R-PERF-021 — Nouvelles références d'inputs
- [ ] R-PERF-022 — `markForCheck` après MAJ via ViewChild
- [ ] R-PERF-023 — `provideZonelessChangeDetection` + zone.js retiré
- [ ] R-PERF-024 — `NgZone.onStable` proscrit
- [ ] R-PERF-025 — `markForCheck` sur `valueChanges` zoneless
- [ ] R-PERF-026 — `PendingTasks` en SSR zoneless
- [ ] R-PERF-027 — Pure pipe pour calculs lents
- [ ] R-PERF-028 — Pas de layout read/write dans hooks
- [ ] R-PERF-029 — `runOutsideAngular` pour libs/timers
- [ ] R-PERF-030 — `ngZone.run` pour MAJ de vue
- [ ] R-PERF-031 — Pas de mutation pendant la CD
- [ ] R-PERF-032 — `enableProfiling()` en dev
- [ ] R-PERF-033 — `[class.x]` / `[style.x]`

---

## Format des findings que doit produire l'agent reviewer

Chaque finding doit suivre ce schéma JSON :

```json
{
  "rule_id": "R-PERF-010",
  "severity": "BLOCKER",
  "file": "src/app/home/home.component.html",
  "line": 12,
  "quote": "<img src=\"hero.jpg\" width=\"1200\" height=\"600\" />",
  "explanation": "L'image utilise `src` au lieu de `ngSrc` ; les optimisations NgOptimizedImage ne s'appliquent pas et le navigateur télécharge avant l'évaluation.",
  "suggestion": "Remplacer `src` par `ngSrc` et ajouter `priority` si l'image est le LCP de la page.",
  "source": "https://angular.dev/best-practices/performance/image-optimization"
}
```

Variante markdown acceptée :

```
- [R-PERF-010 · 🔴 BLOCKER] src/app/home/home.component.html:12
  > <img src="hero.jpg" width="1200" height="600" />
  Explication : `src` annule NgOptimizedImage.
  Suggestion : remplacer par `ngSrc` + `priority` (LCP).
  Source : https://angular.dev/best-practices/performance/image-optimization
```

**Règles de production des findings** :

1. Une entrée par occurrence (ne pas grouper plusieurs lignes sous une seule entrée).
2. Toujours citer le code (`quote`) tel qu'il apparaît dans le diff.
3. Trier le rapport final par sévérité décroissante (BLOCKER → INFO).
4. Si une règle ne s'applique pas (ex. pas de SSR dans le projet), la marquer `n/a` dans la checklist plutôt que de l'omettre.
5. Ne jamais inventer un `rule_id` hors de la liste R-PERF-001…R-PERF-033.
