import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

const SITE = 'https://opennook.dev';

// Reading order for the concatenated dump - matches the site nav.
const ORDER = [
  'start/introduction', 'start/install', 'start/first-nook',
  'guides/theming', 'guides/settings-chrome', 'guides/displays',
  'guides/file-shelf', 'guides/activity-queue', 'guides/volume-glyph',
  'guides/multiple-modules',
  'reference/api', 'reference/troubleshooting',
];

export const GET: APIRoute = async () => {
  const docs = await getCollection('docs');
  const byId = new Map(docs.map((e) => [e.id, e]));

  const ordered = [
    ...ORDER.map((id) => byId.get(id)).filter((e): e is NonNullable<typeof e> => e != null),
    ...docs.filter((e) => !ORDER.includes(e.id)),
  ];

  const blocks = ordered.map((e) => {
    const head = [`# ${e.data.title}`];
    if (e.data.description) head.push('', `> ${e.data.description}`);
    head.push('', `Source: ${SITE}/${e.id}`, '', (e.body ?? '').trim());
    return head.join('\n');
  });

  const out = [
    '# OpenNook - full documentation',
    '',
    '> An open-source Swift framework for building macOS notch apps.',
    '',
    blocks.join('\n\n---\n\n'),
    '',
  ].join('\n');

  return new Response(out, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
