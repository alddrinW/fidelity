import {
  Board,
  FLAPPY_MAX_MS,
  FLAPPY_MIN_MS_PER_PIPE,
  FLAPPY_TARGET,
  HANGMAN_MAX_WRONG,
  HANGMAN_WORDS,
  emptyBoard,
  flappyIsWin,
  guessLetter,
  hangmanStatus,
  hangmanView,
  hangmanWrong,
  newHangman,
  normalizeLetter,
  playTttMove,
  tttComputerMove,
  tttFull,
  tttWinner,
} from './games.logic';

const board = (cells: string): Board =>
  [...cells.replace(/\s/g, '')].map((c) => (c === '.' ? '' : c)) as Board;

describe('ahorcado', () => {
  it('las palabras son letras mayúsculas, sin tildes ni espacios', () => {
    for (const word of HANGMAN_WORDS) expect(word).toMatch(/^[A-ZÑ]+$/);
    expect(new Set(HANGMAN_WORDS).size).toBe(HANGMAN_WORDS.length);
  });

  it('normaliza la letra: mayúscula, sin tilde y la Ñ se conserva', () => {
    expect(normalizeLetter('a')).toBe('A');
    expect(normalizeLetter(' é ')).toBe('E');
    expect(normalizeLetter('ñ')).toBe('Ñ');
    expect(normalizeLetter('ü')).toBe('U');
  });

  it('rechaza lo que no es una sola letra', () => {
    for (const bad of ['', '1', 'ab', '!', ' ']) expect(normalizeLetter(bad)).toBeNull();
  });

  it('elige la palabra con el azar que se le dé', () => {
    expect(newHangman(() => 0).word).toBe(HANGMAN_WORDS[0]);
    expect(newHangman(() => 0.9999).word).toBe(HANGMAN_WORDS[HANGMAN_WORDS.length - 1]);
  });

  it('acertar descubre las letras y no cuenta error', () => {
    let state = { word: 'PIZZA', guessed: [] as string[] };
    state = guessLetter(state, 'Z');

    expect(hangmanWrong(state)).toBe(0);
    expect(hangmanView(state).masked).toEqual(['_', '_', 'Z', 'Z', '_']);
    expect(hangmanStatus(state)).toBe('playing');
  });

  it('una letra repetida no suma error ni se duplica', () => {
    let state = { word: 'PIZZA', guessed: [] as string[] };
    state = guessLetter(state, 'X');
    state = guessLetter(state, 'X');

    expect(state.guessed).toEqual(['X']);
    expect(hangmanWrong(state)).toBe(1);
  });

  it('gana al descubrir todas las letras', () => {
    let state = { word: 'MESA', guessed: [] as string[] };
    for (const l of 'MESA') state = guessLetter(state, l);

    expect(hangmanStatus(state)).toBe('won');
    expect(hangmanView(state).word).toBeUndefined();
  });

  it('pierde al llegar al máximo de errores y entonces se muestra la palabra', () => {
    let state = { word: 'MESA', guessed: [] as string[] };
    for (const l of 'BCDFGH'.slice(0, HANGMAN_MAX_WRONG)) state = guessLetter(state, l);

    expect(hangmanStatus(state)).toBe('lost');
    expect(hangmanView(state).word).toBe('MESA');
  });

  it('la palabra nunca se muestra mientras se juega', () => {
    const view = hangmanView({ word: 'MESA', guessed: ['M'] });

    expect(view.word).toBeUndefined();
    expect(view.masked).toEqual(['M', '_', '_', '_']);
    expect(JSON.stringify(view)).not.toContain('MESA');
  });
});

describe('tres en raya', () => {
  it('detecta cada línea ganadora', () => {
    expect(tttWinner(board('XXX ... ...'))?.winner).toBe('X');
    expect(tttWinner(board('... OOO ...'))?.winner).toBe('O');
    expect(tttWinner(board('X.. X.. X..'))?.line).toEqual([0, 3, 6]);
    expect(tttWinner(board('X.. .X. ..X'))?.line).toEqual([0, 4, 8]);
    expect(tttWinner(board('..O .O. O..'))?.line).toEqual([2, 4, 6]);
    expect(tttWinner(board('XO. ... ...'))).toBeNull();
  });

  it('detecta el tablero lleno', () => {
    expect(tttFull(board('XOX OXO OXO'))).toBe(true);
    expect(tttFull(board('XOX OXO OX.'))).toBe(false);
    expect(tttFull(emptyBoard())).toBe(false);
  });

  describe('la jugada de la computadora (sin azar)', () => {
    const noRandom = () => 0.99; // nunca elige al azar

    it('gana si puede', () => {
      expect(tttComputerMove(board('OO. XX. X..'), noRandom)).toBe(2);
    });

    it('bloquea si el cliente está a una jugada de ganar', () => {
      expect(tttComputerMove(board('XX. .O. ...'), noRandom)).toBe(2);
    });

    it('ganar tiene prioridad sobre bloquear', () => {
      expect(tttComputerMove(board('XX. OO. ...'), noRandom)).toBe(5);
    });

    it('si no hay nada urgente toma el centro, luego una esquina', () => {
      expect(tttComputerMove(board('X.. ... ...'), noRandom)).toBe(4);
      expect([0, 2, 6, 8]).toContain(tttComputerMove(board('... .X. ...'), noRandom));
    });

    it('con una casilla libre juega en ella; sin ninguna devuelve -1', () => {
      expect(tttComputerMove(board('XOX XOO OX.'), noRandom)).toBe(8);
      expect(tttComputerMove(board('XOX XOO OXX'), noRandom)).toBe(-1);
    });

    it('a veces elige al azar para que se pueda ganar', () => {
      // random() < 0.25: jugada al azar entre las libres (la primera, la 0),
      // en lugar de la esquina que elegiría con calma (la 8).
      const position = board('... .X. ...');
      expect(tttComputerMove(position, () => 0)).toBe(0);
      expect(tttComputerMove(position, () => 0.99)).toBe(8);
    });
  });

  describe('una jugada del cliente', () => {
    const noRandom = () => 0.99;

    it('si completa su línea, gana sin que responda la O', () => {
      const result = playTttMove(board('XX. OO. ...'), 2, noRandom);

      expect(result.status).toBe('won');
      expect(result.line).toEqual([0, 1, 2]);
      expect(result.board.filter((c) => c === 'O')).toHaveLength(2);
    });

    it('si la partida sigue, responde la O', () => {
      const result = playTttMove(emptyBoard(), 0, noRandom);

      expect(result.status).toBe('playing');
      expect(result.board[0]).toBe('X');
      expect(result.board[4]).toBe('O'); // el centro
      expect(result.board.filter((c) => c !== '')).toHaveLength(2);
    });

    it('si la O gana con su respuesta, pierde', () => {
      const result = playTttMove(board('OO. X.. X.X'), 3 + 1, noRandom);

      expect(result.status).toBe('lost');
      expect(result.line).toEqual([0, 1, 2]);
    });

    it('un tablero lleno sin ganador es empate', () => {
      const result = playTttMove(board('XOX XOO OX.'), 8, noRandom);

      expect(result.status).toBe('draw');
      expect(result.line).toBeNull();
    });

    it('no modifica el tablero original', () => {
      const original = emptyBoard();
      playTttMove(original, 0, noRandom);

      expect(original.every((c) => c === '')).toBe(true);
    });
  });
});

describe('flappy bird', () => {
  const ok = FLAPPY_TARGET * FLAPPY_MIN_MS_PER_PIPE;

  it('gana con la meta y un tiempo creíble', () => {
    expect(flappyIsWin(FLAPPY_TARGET, ok)).toBe(true);
    expect(flappyIsWin(FLAPPY_TARGET + 5, (FLAPPY_TARGET + 5) * FLAPPY_MIN_MS_PER_PIPE)).toBe(true);
  });

  it('no gana si no llega a la meta', () => {
    expect(flappyIsWin(FLAPPY_TARGET - 1, ok)).toBe(false);
  });

  it('no gana si el tiempo es imposible (puntaje inventado)', () => {
    expect(flappyIsWin(FLAPPY_TARGET, 2000)).toBe(false);
    expect(flappyIsWin(100, 5000)).toBe(false);
  });

  it('no gana si se pasó del tiempo máximo', () => {
    expect(flappyIsWin(FLAPPY_TARGET, FLAPPY_MAX_MS + 1)).toBe(false);
  });
});
