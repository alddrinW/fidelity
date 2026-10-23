/**
 * Los ajustes que el administrador controla desde la app. Cada uno tiene su
 * límite (para que nadie deje el sistema inservible) y un valor por defecto:
 * mientras el administrador no lo cambie, se usa ese.
 */
export type SettingGroup = 'precios' | 'minijuegos' | 'negocios' | 'cumpleanos' | 'datos';

export type SettingKind = 'money' | 'int';

export interface SettingDefinition {
  key: string;
  group: SettingGroup;
  kind: SettingKind;
  label: string;
  description: string;
  /** "USD", "días", "intentos"... se muestra junto al valor. */
  unit: string;
  min: number;
  max: number;
  default: number;
  /** Clave de la configuración del servidor que da el valor por defecto, si la hay. */
  configPath?: string;
}

/** Orden en que se muestran los grupos. */
export const SETTING_GROUPS: { id: SettingGroup; label: string; description: string }[] = [
  { id: 'precios', label: 'Precios', description: 'Lo que paga un dueño para activar su cuenta.' },
  { id: 'minijuegos', label: 'Minijuegos', description: 'Reglas de los juegos que los locales mandan a sus clientes.' },
  { id: 'negocios', label: 'Negocios', description: 'Límites de cada local.' },
  { id: 'cumpleanos', label: 'Cumpleaños', description: 'Cuándo se avisa a los dueños de los cumpleaños de sus clientes.' },
  { id: 'datos', label: 'Limpieza de datos', description: 'Cuánto tiempo se guardan los registros viejos antes de borrarse solos.' },
];

export const SETTING_KEYS = {
  registrationFee: 'registration_fee',
  branchFee: 'branch_fee',
  gameMaxAttempts: 'game_max_attempts',
  gameDefaultDays: 'game_default_days',
  gameMaxDays: 'game_max_days',
  gameMaxAudience: 'game_max_audience',
  fidelyScansRequired: 'fidely_scans_required',
  maxApprovers: 'max_approvers',
  maxFeedbackPerDay: 'max_feedback_per_day',
  birthdayNoticeHour: 'birthday_notice_hour',
  birthdayUpcomingDays: 'birthday_upcoming_days',
  keepReadNotificationsDays: 'keep_read_notifications_days',
  keepNotificationsDays: 'keep_notifications_days',
  keepScanAttemptsDays: 'keep_scan_attempts_days',
  keepGameInvitesDays: 'keep_game_invites_days',
} as const;

export const SETTING_DEFINITIONS: SettingDefinition[] = [
  {
    key: SETTING_KEYS.registrationFee,
    group: 'precios',
    kind: 'money',
    label: 'Registro de negocio',
    description: 'Lo que paga el dueño para activar su negocio. Vale para los pagos nuevos; los ya emitidos conservan su monto.',
    unit: 'USD',
    min: 0.5,
    max: 10000,
    default: 20,
    configPath: 'payments.registrationFee',
  },
  {
    key: SETTING_KEYS.branchFee,
    group: 'precios',
    kind: 'money',
    label: 'Alta de sucursal',
    description: 'Lo que paga el dueño por cada sucursal nueva.',
    unit: 'USD',
    min: 0.5,
    max: 10000,
    default: 10,
    configPath: 'payments.branchFee',
  },
  {
    key: SETTING_KEYS.gameMaxAttempts,
    group: 'minijuegos',
    kind: 'int',
    label: 'Intentos por reto',
    description: 'Cuántas veces puede jugar un cliente para ganar cada juego que le manda un local.',
    unit: 'intentos',
    min: 1,
    max: 10,
    default: 3,
  },
  {
    key: SETTING_KEYS.gameDefaultDays,
    group: 'minijuegos',
    kind: 'int',
    label: 'Duración si el local no pone fin',
    description: 'Cuánto dura un reto cuando el dueño no elige la hora de fin.',
    unit: 'días',
    min: 1,
    max: 30,
    default: 7,
  },
  {
    key: SETTING_KEYS.gameMaxDays,
    group: 'minijuegos',
    kind: 'int',
    label: 'Duración máxima de un reto',
    description: 'Lo más largo que puede ser el horario de un reto.',
    unit: 'días',
    min: 1,
    max: 365,
    default: 90,
  },
  {
    key: SETTING_KEYS.gameMaxAudience,
    group: 'minijuegos',
    kind: 'int',
    label: 'Clientes por envío',
    description: 'A cuántos clientes como máximo se les manda un juego de una vez.',
    unit: 'clientes',
    min: 10,
    max: 5000,
    default: 1000,
  },
  {
    key: SETTING_KEYS.fidelyScansRequired,
    group: 'negocios',
    kind: 'int',
    label: 'Escaneos para ser FidelyUsuario',
    description: 'Cuántos escaneos aprobados necesita un cliente en un mismo local para recibir la insignia FidelyUsuario de ese local.',
    unit: 'escaneos',
    min: 1,
    max: 50,
    default: 3,
  },
  {
    key: SETTING_KEYS.maxApprovers,
    group: 'negocios',
    kind: 'int',
    label: 'Aprobadores por negocio',
    description: 'Cuántas personas puede tener un negocio aprobando los códigos QR y las gift cards.',
    unit: 'personas',
    min: 1,
    max: 50,
    default: 10,
  },
  {
    key: SETTING_KEYS.maxFeedbackPerDay,
    group: 'negocios',
    kind: 'int',
    label: 'Opiniones por cliente y local al día',
    description: 'Cuántas sugerencias o reclamos puede mandar un cliente al mismo local en 24 horas.',
    unit: 'opiniones',
    min: 1,
    max: 20,
    default: 3,
  },
  {
    key: SETTING_KEYS.birthdayNoticeHour,
    group: 'cumpleanos',
    kind: 'int',
    label: 'Hora del aviso de cumpleaños',
    description: 'A partir de qué hora (de 0 a 23, hora de Ecuador) se le avisa al dueño que un cliente cumple años hoy.',
    unit: 'h',
    min: 0,
    max: 23,
    default: 8,
  },
  {
    key: SETTING_KEYS.birthdayUpcomingDays,
    group: 'cumpleanos',
    kind: 'int',
    label: 'Cumpleaños próximos que ve el dueño',
    description: 'Con cuántos días de anticipación ve el dueño los cumpleaños de sus clientes y puede regalarles.',
    unit: 'días',
    min: 1,
    max: 30,
    default: 7,
  },
  {
    key: SETTING_KEYS.keepReadNotificationsDays,
    group: 'datos',
    kind: 'int',
    label: 'Avisos ya leídos',
    description: 'Los avisos que el cliente ya leyó se borran pasado este tiempo.',
    unit: 'días',
    min: 7,
    max: 365,
    default: 30,
  },
  {
    key: SETTING_KEYS.keepNotificationsDays,
    group: 'datos',
    kind: 'int',
    label: 'Cualquier aviso',
    description: 'Todo aviso, leído o no, se borra pasado este tiempo.',
    unit: 'días',
    min: 30,
    max: 730,
    default: 90,
  },
  {
    key: SETTING_KEYS.keepScanAttemptsDays,
    group: 'datos',
    kind: 'int',
    label: 'Registro de intentos de escaneo',
    description: 'Los intentos de escaneo (válidos o no) se borran pasado este tiempo.',
    unit: 'días',
    min: 30,
    max: 730,
    default: 90,
  },
  {
    key: SETTING_KEYS.keepGameInvitesDays,
    group: 'datos',
    kind: 'int',
    label: 'Retos de minijuegos terminados',
    description: 'Los retos ya terminados o vencidos se borran pasado este tiempo.',
    unit: 'días',
    min: 30,
    max: 730,
    default: 90,
  },
];

/** Ajustes que no son un número sino una lista (se guardan como JSON). */
export const BANK_ACCOUNTS_KEY = 'bank_accounts';
export const JSON_SETTING_KEYS: string[] = [BANK_ACCOUNTS_KEY];

export const SETTING_BY_KEY: Record<string, SettingDefinition> = Object.fromEntries(
  SETTING_DEFINITIONS.map((d) => [d.key, d]),
);
