/**
 * Reglas de los minijuegos. Son funciones puras (sin base de datos) para que
 * se puedan probar a fondo: el servidor es quien decide quién gana.
 */

export const GAME_KEYS = ['tictactoe', 'hangman', 'flappy'] as const;
export type GameKey = (typeof GAME_KEYS)[number];

export const GAME_NAMES: Record<GameKey, string> = {
  tictactoe: 'Tres en raya',
  hangman: 'Ahorcado',
  flappy: 'Flappy Bird',
};

export function isGameKey(value: string): value is GameKey {
  return (GAME_KEYS as readonly string[]).includes(value);
}

// ---------------------------------------------------------------------------
// Ahorcado
// ---------------------------------------------------------------------------

export const HANGMAN_MAX_WRONG = 6;

// Palabras de la vida diaria de un local (sin tildes; la Ñ cuenta como letra).
export const HANGMAN_WORDS = [
  'CAFETERIA', 'PANADERIA', 'HELADO', 'CHOCOLATE', 'SANDWICH', 'ENSALADA', 'PIZZA', 'HAMBURGUESA',
  'BATIDO', 'JUGO', 'GALLETA', 'PASTEL', 'CROISSANT', 'EMPANADA', 'TOSTADA', 'DESAYUNO',
  'ALMUERZO', 'MERIENDA', 'PROPINA', 'PREMIO', 'PUNTOS', 'TARJETA', 'DESCUENTO', 'FIDELIDAD',
  'CLIENTE', 'SORPRESA', 'REGALO', 'CUMPLEAÑOS', 'AMIGOS', 'FAMILIA', 'SABOR', 'AROMA',
  'MENU', 'COMBO', 'BEBIDA', 'POSTRE', 'CAPUCHINO', 'ESPRESSO', 'LIMONADA', 'MANZANA',
  'NARANJA', 'FRUTILLA', 'BANANA', 'AGUACATE', 'QUESO', 'JAMON', 'TOMATE', 'CEBOLLA',
  'PESCADO', 'MARISCOS', 'ARROZ', 'FIDEOS', 'SOPA', 'ASADO', 'PARRILLA', 'COCINA',
  'MESERO', 'MESA', 'TERRAZA', 'VENTANA',
];

export interface HangmanState {
  word: string;
  guessed: string[];
}

/** Quita tildes y pasa a mayúscula; la Ñ se conserva. */
export function normalizeLetter(raw: string): string | null {
  const letter = raw
    .trim()
    .toUpperCase()
    .replace(/Ñ/g, '\u0001')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\u0001/g, 'Ñ');
  return /^[A-ZÑ]$/.test(letter) ? letter : null;
}

export function newHangman(random: () => number = Math.random): HangmanState {
  const word = HANGMAN_WORDS[Math.floor(random() * HANGMAN_WORDS.length)];
  return { word, guessed: [] };
}

export function hangmanWrong(state: HangmanState): number {
  return state.guessed.filter((l) => !state.word.includes(l)).length;
}

export type HangmanStatus = 'playing' | 'won' | 'lost';

export function hangmanStatus(state: HangmanState): HangmanStatus {
  if (hangmanWrong(state) >= HANGMAN_MAX_WRONG) return 'lost';
  if ([...state.word].every((c) => state.guessed.includes(c))) return 'won';
  return 'playing';
}

/** Aplica una letra. Una letra repetida no cuenta como error. */
export function guessLetter(state: HangmanState, letter: string): HangmanState {
  if (state.guessed.includes(letter)) return state;
  return { ...state, guessed: [...state.guessed, letter] };
}

/** Lo que ve el cliente: la palabra con guiones; la palabra entera solo si perdió. */
export function hangmanView(state: HangmanState) {
  const status = hangmanStatus(state);
  return {
    masked: [...state.word].map((c) => (state.guessed.includes(c) ? c : '_')),
    guessed: state.guessed,
    wrong: hangmanWrong(state),
    maxWrong: HANGMAN_MAX_WRONG,
    status,
    word: status === 'lost' ? state.word : undefined,
  };
}

// ---------------------------------------------------------------------------
// Tres en raya (el cliente es X y empieza; el servidor juega la O)
// ---------------------------------------------------------------------------

export type Cell = '' | 'X' | 'O';
export type Board = Cell[];

const LINES = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

export function emptyBoard(): Board {
  return Array(9).fill('') as Board;
}

export function tttWinner(board: Board): { winner: 'X' | 'O'; line: number[] } | null {
  for (const line of LINES) {
    const [a, b, c] = line;
    if (board[a] && board[a] === board[b] && board[a] === board[c]) {
      return { winner: board[a] as 'X' | 'O', line };
    }
  }
  return null;
}

export const tttFull = (board: Board) => board.every((c) => c !== '');

function findLineCompletion(board: Board, mark: 'X' | 'O'): number | null {
  for (const line of LINES) {
    const marks = line.filter((i) => board[i] === mark).length;
    const empty = line.find((i) => board[i] === '');
    if (marks === 2 && empty !== undefined) return empty;
  }
  return null;
}

/**
 * La jugada de la O: gana si puede, bloquea si hace falta y, si no, juega al
 * centro, a una esquina o a un lado. Una de cada 4 veces elige al azar para que
 * el juego se pueda ganar.
 */
export function tttComputerMove(board: Board, random: () => number = Math.random): number {
  const free = board.map((c, i) => (c === '' ? i : -1)).filter((i) => i >= 0);
  if (free.length === 0) return -1;
  if (random() < 0.25) return free[Math.floor(random() * free.length)];

  const win = findLineCompletion(board, 'O');
  if (win !== null) return win;
  const block = findLineCompletion(board, 'X');
  if (block !== null) return block;
  if (board[4] === '') return 4;
  const corners = [0, 2, 6, 8].filter((i) => board[i] === '');
  if (corners.length > 0) return corners[Math.floor(random() * corners.length)];
  return free[Math.floor(random() * free.length)];
}

export type TttStatus = 'playing' | 'won' | 'lost' | 'draw';

export interface TttResult {
  board: Board;
  status: TttStatus;
  line: number[] | null;
}

/** El cliente juega en `cell` y, si la partida sigue, responde la O. */
export function playTttMove(
  board: Board,
  cell: number,
  random: () => number = Math.random,
): TttResult {
  const next = [...board] as Board;
  next[cell] = 'X';

  const afterPlayer = tttWinner(next);
  if (afterPlayer) return { board: next, status: 'won', line: afterPlayer.line };
  if (tttFull(next)) return { board: next, status: 'draw', line: null };

  const reply = tttComputerMove(next, random);
  next[reply] = 'O';
  const afterComputer = tttWinner(next);
  if (afterComputer) return { board: next, status: 'lost', line: afterComputer.line };
  if (tttFull(next)) return { board: next, status: 'draw', line: null };
  return { board: next, status: 'playing', line: null };
}

// ---------------------------------------------------------------------------
// Flappy Bird (el cliente juega solo; el servidor comprueba que sea creíble)
// ---------------------------------------------------------------------------

/** Tubos que hay que pasar para ganar. */
export const FLAPPY_TARGET = 10;

/** Lo mínimo que tarda un tubo en pasarse; menos que eso no es humano. */
export const FLAPPY_MIN_MS_PER_PIPE = 1100;

/** Después de este tiempo la partida se da por perdida. */
export const FLAPPY_MAX_MS = 10 * 60 * 1000;

export function flappyIsWin(score: number, durationMs: number): boolean {
  return (
    score >= FLAPPY_TARGET &&
    durationMs >= score * FLAPPY_MIN_MS_PER_PIPE &&
    durationMs <= FLAPPY_MAX_MS
  );
}
