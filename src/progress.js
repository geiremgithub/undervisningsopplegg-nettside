const EXPORT_FORMAT = 'undervisningsopplegg-progresjon';
export const GUEST_NAME = 'Gjest';
export const MAX_NAME_LENGTH = 50;

function memoryStorage() {
  const data = new Map();
  return {
    getItem: (k) => (data.has(k) ? data.get(k) : null),
    setItem: (k, v) => data.set(k, String(v)),
    removeItem: (k) => data.delete(k),
  };
}

/** Returnerer localStorage hvis den er tilgjengelig, ellers lagring i minnet (f.eks. ved blokkerte informasjonskapsler). */
export function safeStorage() {
  try {
    const probe = '__probe__';
    window.localStorage.setItem(probe, probe);
    window.localStorage.removeItem(probe);
    return { storage: window.localStorage, persistent: true };
  } catch {
    return { storage: memoryStorage(), persistent: false };
  }
}

export function normalizeName(name) {
  return String(name ?? '').replace(/\s+/g, ' ').trim().slice(0, MAX_NAME_LENGTH);
}

const uniq = (list) => [...new Set(list.filter((s) => typeof s === 'string' && s))];

export function createProgressStore(storage, namespace, { legacy = [] } = {}) {
  const usersKey = `${namespace}:brukere`;
  const activeKey = `${namespace}:aktiv-bruker`;

  function readUsers() {
    try {
      const parsed = JSON.parse(storage.getItem(usersKey) ?? '{}');
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch {
      return {};
    }
  }

  function writeUsers(users) {
    storage.setItem(usersKey, JSON.stringify(users));
  }

  // Navn matches uten hensyn til store/små bokstaver, så «kari» og «Kari» blir samme bruker.
  function findKey(users, name) {
    const wanted = normalizeName(name).toLocaleLowerCase('nb');
    return Object.keys(users).find((k) => k.toLocaleLowerCase('nb') === wanted);
  }

  function ensureUser(users, name) {
    const clean = normalizeName(name) || GUEST_NAME;
    const key = findKey(users, clean) ?? clean;
    users[key] ??= { started: [], completed: [] };
    users[key].started = uniq(users[key].started ?? []);
    users[key].completed = uniq(users[key].completed ?? []);
    return key;
  }

  function update(mutator) {
    const name = getCurrentUser();
    if (!name) return;
    const users = readUsers();
    const key = ensureUser(users, name);
    mutator(users[key]);
    users[key].updatedAt = new Date().toISOString();
    writeUsers(users);
  }

  function getCurrentUser() {
    const name = storage.getItem(activeKey);
    if (!name) return null;
    return findKey(readUsers(), name) ?? null;
  }

  function setCurrentUser(name) {
    const users = readUsers();
    const key = ensureUser(users, name);
    writeUsers(users);
    storage.setItem(activeKey, key);
    return key;
  }

  function getProgress(name = getCurrentUser()) {
    const users = readUsers();
    const key = name ? findKey(users, name) : undefined;
    const user = key ? users[key] : undefined;
    return { started: new Set(user?.started ?? []), completed: new Set(user?.completed ?? []) };
  }

  function getStatus(slug) {
    const { started, completed } = getProgress();
    if (completed.has(slug)) return 'fullfort';
    if (started.has(slug)) return 'pagar';
    return 'ikke-startet';
  }

  // Legger til tema-ID-er hos en bruker uten å fjerne noe.
  function mergeInto(users, name, started, completed) {
    const key = ensureUser(users, name);
    users[key].started = uniq([...users[key].started, ...started, ...completed]);
    users[key].completed = uniq([...users[key].completed, ...completed]);
    users[key].updatedAt = new Date().toISOString();
    return key;
  }

  const asList = (value) => (Array.isArray(value) ? value.filter((s) => typeof s === 'string') : []);
  const withPrefix = (prefix, ids) => asList(ids).map((id) => `${prefix}/${id}`);

  /**
   * Henter progresjon fra tidligere versjoner av nettstedet, der alt var ett emne uten prefiks i ID-ene.
   * Kjøres én gang per gammel lagringsnøkkel.
   */
  function migrateLegacy() {
    for (const { storageKey, emne } of legacy) {
      const flag = `${namespace}:migrert:${storageKey}`;
      if (!storageKey || !emne || storage.getItem(flag)) continue;
      let old = null;
      try {
        old = JSON.parse(storage.getItem(`${storageKey}:brukere`) ?? 'null');
      } catch {
        old = null;
      }
      if (old && typeof old === 'object' && !Array.isArray(old)) {
        const users = readUsers();
        for (const [name, user] of Object.entries(old)) {
          mergeInto(users, name, withPrefix(emne, user?.started), withPrefix(emne, user?.completed));
        }
        writeUsers(users);
        const oldActive = storage.getItem(`${storageKey}:aktiv-bruker`);
        if (oldActive && !storage.getItem(activeKey)) storage.setItem(activeKey, findKey(users, oldActive) ?? oldActive);
      }
      storage.setItem(flag, new Date().toISOString());
    }
  }

  return {
    getCurrentUser,
    setCurrentUser,
    getProgress,
    getStatus,
    migrateLegacy,
    listUsers: () => Object.keys(readUsers()).sort((a, b) => a.localeCompare(b, 'nb')),
    getLastVisited() {
      const name = getCurrentUser();
      return name ? readUsers()[name]?.lastVisited ?? null : null;
    },
    markStarted: (slug) =>
      update((u) => {
        if (!u.started.includes(slug)) u.started.push(slug);
        u.lastVisited = slug;
      }),
    setCompleted: (slug, done) =>
      update((u) => {
        u.completed = done ? uniq([...u.completed, slug]) : u.completed.filter((s) => s !== slug);
        if (!u.started.includes(slug)) u.started.push(slug);
      }),
    reset: () =>
      update((u) => {
        u.started = [];
        u.completed = [];
      }),
    exportData() {
      const name = getCurrentUser();
      const { started, completed } = getProgress(name);
      return {
        format: EXPORT_FORMAT,
        versjon: 1,
        kurs: namespace,
        navn: name,
        startet: [...started],
        fullfort: [...completed],
        eksportert: new Date().toISOString(),
      };
    },
    /** Slår sammen importert progresjon med eksisterende (ingenting slettes) og bytter til brukeren i filen. */
    importData(data) {
      if (!data || data.format !== EXPORT_FORMAT || !Array.isArray(data.fullfort) || !Array.isArray(data.startet)) {
        throw new Error('Filen er ikke en gyldig progresjonsfil fra dette nettstedet.');
      }
      let started = asList(data.startet);
      let completed = asList(data.fullfort);
      if (data.kurs && data.kurs !== namespace) {
        // Filer eksportert fra en tidligere versjon av nettstedet får emnet foran tema-ID-ene.
        const match = legacy.find((l) => l.storageKey === data.kurs);
        if (!match) throw new Error('Filen tilhører et annet undervisningsopplegg.');
        started = withPrefix(match.emne, started);
        completed = withPrefix(match.emne, completed);
      }
      const users = readUsers();
      const key = mergeInto(users, data.navn || getCurrentUser() || GUEST_NAME, started, completed);
      writeUsers(users);
      storage.setItem(activeKey, key);
      return key;
    },
  };
}
