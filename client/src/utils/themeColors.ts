function hexToHsl(hex: string): [number, number, number] {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;

  if (max === min) return [0, 0, l];

  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

  let h: number;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;

  return [h * 360, s, l];
}

function hslToHex(h: number, s: number, l: number): string {
  h = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs((h / 60) % 2 - 1));
  const m = l - c / 2;

  let r = 0, g = 0, b = 0;
  if (h < 60) { r = c; g = x; }
  else if (h < 120) { r = x; g = c; }
  else if (h < 180) { g = c; b = x; }
  else if (h < 240) { g = x; b = c; }
  else if (h < 300) { r = x; b = c; }
  else { r = c; b = x; }

  const toHex = (v: number) =>
    Math.round(Math.min(255, Math.max(0, (v + m) * 255)))
      .toString(16)
      .padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

export function deriveThemeColors(primaryHex: string) {
  const [h] = hexToHsl(primaryHex);

  return {
    light: {
      primary: primaryHex,
      background: hslToHex(h, 0.10, 0.98),
      surface: '#ffffff',
      'surface-bright': hslToHex(h, 0.10, 0.98),
      'surface-variant': hslToHex(h, 0.18, 0.93),
      'on-surface-variant': hslToHex(h, 0.08, 0.40),
    },
    dark: {
      primary: primaryHex,
      background: hslToHex(h, 0.06, 0.07),
      surface: hslToHex(h, 0.07, 0.12),
      'surface-bright': hslToHex(h, 0.08, 0.17),
      'surface-variant': hslToHex(h, 0.06, 0.21),
      secondary: hslToHex((h + 60) % 360, 0.45, 0.75),
      'on-surface': hslToHex(h, 0.03, 0.95),
      'on-surface-variant': hslToHex(h, 0.05, 0.78),
    },
  };
}
