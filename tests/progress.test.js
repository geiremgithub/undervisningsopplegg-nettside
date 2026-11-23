import { describe, expect, it } from 'vitest';
import { createProgressStore } from '../src/progress.js';

function memory() {
  const data = new Map();
  return { getItem: (k) => data.get(k) ?? null, setItem: (k, v) => data.set(k, String(v)), removeItem: (k) => data.delete(k) };
}

describe('progresjon', () => {
  it('holder progresjon adskilt per bruker og matcher navn uten hensyn til store bokstaver', () => {
    const store = createProgressStore(memory(), 'kurs');
    store.setCurrentUser('Kari');
    store.setCompleted('a', true);
    store.setCurrentUser('Ola');
    expect(store.getStatus('a')).toBe('ikke-startet');
    expect(store.setCurrentUser('kari')).toBe('Kari');
    expect(store.getStatus('a')).toBe('fullfort');
    expect(store.listUsers()).toEqual(['Kari', 'Ola']);
  });

  it('går tilbake til «pågår» når fullført angres', () => {
    const store = createProgressStore(memory(), 'kurs');
    store.setCurrentUser('Kari');
    store.markStarted('a');
    expect(store.getStatus('a')).toBe('pagar');
    store.setCompleted('a', true);
    store.setCompleted('a', false);
    expect(store.getStatus('a')).toBe('pagar');
  });

  it('nullstiller bare den aktive brukeren', () => {
    const store = createProgressStore(memory(), 'kurs');
    store.setCurrentUser('Kari');
    store.setCompleted('a', true);
    store.setCurrentUser('Ola');
    store.setCompleted('a', true);
    store.reset();
    expect(store.getStatus('a')).toBe('ikke-startet');
    store.setCurrentUser('Kari');
    expect(store.getStatus('a')).toBe('fullfort');
  });

  it('slår sammen importert progresjon og bytter til brukeren i filen', () => {
    const storage = memory();
    const source = createProgressStore(storage, 'kurs');
    source.setCurrentUser('Kari');
    source.setCompleted('a', true);
    const exported = source.exportData();

    const target = createProgressStore(memory(), 'kurs');
    target.setCurrentUser('Kari');
    target.setCompleted('b', true);
    target.setCurrentUser('Ola');
    expect(target.importData(exported)).toBe('Kari');
    expect(target.getCurrentUser()).toBe('Kari');
    expect([...target.getProgress().completed].sort()).toEqual(['a', 'b']);
  });

  it('avviser filer med feil format eller fra et annet kurs', () => {
    const store = createProgressStore(memory(), 'kurs');
    expect(() => store.importData({ hei: 1 })).toThrow(/gyldig/);
    const other = createProgressStore(memory(), 'annet-kurs');
    other.setCurrentUser('Kari');
    expect(() => store.importData(other.exportData())).toThrow(/annet/);
  });

  it('henter progresjon fra den gamle ett-emne-lagringen én gang, med emnet som prefiks', () => {
    const storage = memory();
    storage.setItem('gammel:brukere', JSON.stringify({ Kari: { started: ['a', 'b'], completed: ['a'] } }));
    storage.setItem('gammel:aktiv-bruker', 'Kari');
    const legacy = [{ storageKey: 'gammel', emne: 'dv' }];
    const store = createProgressStore(storage, 'kurs', { legacy });
    store.migrateLegacy();
    expect(store.getCurrentUser()).toBe('Kari');
    expect(store.getStatus('dv/a')).toBe('fullfort');
    expect(store.getStatus('dv/b')).toBe('pagar');
    store.setCompleted('dv/a', false);
    store.migrateLegacy();
    expect(store.getStatus('dv/a')).toBe('pagar');
  });

  it('importerer eksportfiler fra den gamle versjonen med emnet som prefiks', () => {
    const old = createProgressStore(memory(), 'gammel');
    old.setCurrentUser('Kari');
    old.setCompleted('a', true);
    const store = createProgressStore(memory(), 'kurs', { legacy: [{ storageKey: 'gammel', emne: 'dv' }] });
    store.importData(old.exportData());
    expect(store.getStatus('dv/a')).toBe('fullfort');
  });

  it('husker sist besøkte tema per bruker', () => {
    const store = createProgressStore(memory(), 'kurs');
    store.setCurrentUser('Kari');
    store.markStarted('dv/a');
    store.markStarted('dv/b');
    expect(store.getLastVisited()).toBe('dv/b');
    store.setCurrentUser('Ola');
    expect(store.getLastVisited()).toBeNull();
  });

  it('tåler ødelagte data i lagringen', () => {
    const storage = memory();
    storage.setItem('kurs:brukere', '{ikke json');
    const store = createProgressStore(storage, 'kurs');
    expect(store.setCurrentUser('Kari')).toBe('Kari');
    expect(store.getStatus('a')).toBe('ikke-startet');
  });
});
