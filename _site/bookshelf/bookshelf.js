const baseURL = new URL('.', import.meta.url);
const assetURL = path => new URL(path, baseURL).href;
const SVG = 'http://www.w3.org/2000/svg';

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function externalLink(href, label) {
  try {
    const url = new URL(href);
    if (url.protocol !== 'https:') return null;
    const link = element('a', '', label);
    link.href = url.href;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    return link;
  } catch { return null; }
}

class VirtualBookshelf extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.view = '3d';
    this.photoIndex = 0;
  }

  connectedCallback() {
    if (this.abort) return;
    this.abort = new AbortController();
    this.initialize(this.abort.signal);
  }

  disconnectedCallback() {
    this.abort?.abort();
    this.abort = null;
    this.scene?.dispose();
    this.scene = null;
    this.dialog?.close();
  }

  async initialize(signal) {
    this.shadowRoot.innerHTML = `
      <link rel="stylesheet" href="${assetURL('bookshelf.css')}">
      <div class="toolbar">
        <div class="navigation">
          <select class="shelf-select" aria-label="Focus on a shelf"><option value="all">All shelves</option></select>
          <label class="photo-select-label" hidden>Photo <select class="photo-select"><option value="0">Left shelves</option><option value="1">Right shelves</option></select></label>
        </div>
      </div>
      <div class="stage">
        <canvas tabindex="0" role="img" aria-label="Interactive bookshelf. Drag to rotate, scroll to zoom. Use arrow keys to choose a book and Enter to open it. You can also use the book list below."></canvas>
        <div class="photo-view" hidden></div>
        <div class="hover-label" hidden aria-live="polite"></div>
        <div class="loading" role="status">Opening the shelves…<small>Your books, in their new places.</small></div>
      </div>
      <div class="caption"><span class="instructions">Drag to turn · Scroll or pinch to zoom · Click a spine to open</span><span class="count"></span></div>
      <section class="shelf-index"><h2 class="index-title">Browse all books</h2><ul class="index-list"></ul></section>
      <dialog class="book-dialog" aria-labelledby="book-title" aria-describedby="book-description">
        <div class="dialog-bar"><span class="dialog-location"></span><button type="button" class="close" aria-label="Close book details" autofocus>×</button></div>
        <div class="dialog-body"><figure class="cover-figure"></figure><div><p class="eyebrow"></p><h2 class="book-title" id="book-title"></h2><p class="author"></p><p class="description" id="book-description"></p><dl class="book-meta"></dl><div class="source-links"></div></div></div>
        <div class="dialog-footer"><button type="button" class="previous">← Previous book</button><button type="button" class="next">Next book →</button></div>
      </dialog>`;
    this.$ = selector => this.shadowRoot.querySelector(selector);
    this.dialog = this.$('dialog');
    const listen = (node, event, callback) => node.addEventListener(event, callback, { signal });
    listen(this.$('.shelf-select'), 'change', event => this.focusShelf(event.target.value));
    listen(this.$('.photo-select'), 'change', event => { this.photoIndex = Number(event.target.value); this.$('.shelf-select').value = 'all'; this.renderPhoto(); });
    listen(this.$('.close'), 'click', () => this.dialog.close());
    listen(this.dialog, 'click', event => {
      const rect = this.dialog.getBoundingClientRect();
      if (event.target === this.dialog && (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom)) this.dialog.close();
    });
    listen(this.dialog, 'close', () => this.returnFocus?.focus({ preventScroll: true }));
    listen(this.$('.previous'), 'click', () => this.stepBook(-1));
    listen(this.$('.next'), 'click', () => this.stepBook(1));
    try {
      const response = await fetch(assetURL('assets/catalog.json'), { signal });
      if (!response.ok) throw new Error('Catalog could not load.');
      this.catalog = await response.json();
      if (signal.aborted) return;
      this.byID = new Map(this.catalog.books.map(book => [book.id, book]));
      this.populateBooks(listen);
      this.renderPhoto();
      // The photo view and book list remain usable if WebGL is unavailable.
      try {
        const [{ ShelfScene, makeSpines }, images] = await Promise.all([
          import('./scene.js'),
          Promise.all(this.catalog.photos.map(photo => new Promise((resolve, reject) => {
            const image = new Image();
            image.onload = () => resolve(image);
            image.onerror = () => reject(new Error('Photograph could not load.'));
            image.src = assetURL(photo.src);
          })))
        ]);
        if (signal.aborted) return;
        this.spines = makeSpines(images, this.catalog.books);
        this.scene = new ShelfScene(this.$('canvas'), this.catalog, this.spines, {
          select: book => this.openBook(book), hover: book => this.showHover(book)
        }, assetURL);
        this.setView(this.view);
      } catch (error) {
        if (signal.aborted) return;
        this.setView('photo');
        console.warn('Bookshelf: using photo view.', error);
      }
      this.$('.loading').hidden = true;
    } catch (error) {
      if (signal.aborted) return;
      const message = element('div', 'error-message', 'The bookshelf could not load. Serve this folder from a website or local web server, then try again.');
      const retry = element('button', '', 'Try again');
      listen(retry, 'click', () => { this.disconnectedCallback(); this.connectedCallback(); });
      message.append(document.createElement('br'), retry);
      this.$('.loading').replaceChildren(message);
      console.error('Bookshelf:', error);
    }
  }

  populateBooks(listen) {
    const shelves = [...new Set(this.catalog.books.map(book => book.shelf))].sort();
    for (const shelf of shelves) this.$('.shelf-select').add(new Option(`${shelf} · ${this.catalog.books.filter(book => book.shelf === shelf).length} books`, shelf));
    const fragment = document.createDocumentFragment();
    for (const book of this.catalog.books) {
      const li = element('li');
      const button = element('button');
      button.type = 'button';
      button.append(element('span', 'location', book.shelf), element('span', 'name', book.title));
      listen(button, 'click', () => this.openBook(book));
      li.append(button);
      fragment.append(li);
    }
    this.$('.index-list').append(fragment);
    this.$('.count').textContent = `${this.catalog.books.length} books · 12 shelves`;
  }

  setView(view) {
    this.view = view;
    this.$('canvas').hidden = view !== '3d';
    this.$('.photo-view').hidden = view !== 'photo';
    this.$('.photo-select-label').hidden = view !== 'photo';
    this.showHover(null);
    this.$('.instructions').textContent = view === '3d'
      ? 'Drag to turn · Scroll or pinch to zoom · Click a spine to open'
      : 'Click a book in the photograph · Choose a shelf for a closer look';
    if (view === '3d') this.scene?.resize();
    else if (this.catalog) this.renderPhoto();
  }

  focusShelf(shelf) {
    this.$('.shelf-select').value = shelf;
    this.scene?.focusShelf(shelf);
    if (shelf !== 'all') this.photoIndex = shelf[0] < 'C' ? 0 : 1;
    if (this.catalog) this.renderPhoto();
  }

  renderPhoto() {
    const photo = this.catalog.photos[this.photoIndex];
    const shelf = this.$('.shelf-select').value;
    const books = this.catalog.books.filter(book => book.photo === this.photoIndex);
    const svg = document.createElementNS(SVG, 'svg');
    let bounds = [0, 0, photo.width, photo.height];
    if (shelf !== 'all') {
      const points = books.filter(book => book.shelf === shelf).flatMap(book => book.quad);
      if (points.length) {
        const left = Math.max(0, Math.min(...points.map(p => p[0])) - 24);
        const top = Math.max(0, Math.min(...points.map(p => p[1])) - 24);
        bounds = [left, top, Math.min(photo.width, Math.max(...points.map(p => p[0])) + 24) - left, Math.min(photo.height, Math.max(...points.map(p => p[1])) + 24) - top];
      }
    }
    svg.setAttribute('viewBox', bounds.join(' '));
    svg.setAttribute('aria-label', `${photo.label}. Select a book for details.`);
    const image = document.createElementNS(SVG, 'image');
    image.setAttribute('href', assetURL(photo.src));
    image.setAttribute('width', photo.width);
    image.setAttribute('height', photo.height);
    svg.append(image);
    for (const book of books.filter(book => shelf === 'all' || book.shelf === shelf)) {
      const link = document.createElementNS(SVG, 'a');
      link.setAttribute('href', `#book-${book.id}`);
      link.setAttribute('role', 'button');
      link.setAttribute('aria-label', `${book.title}, shelf ${book.shelf}`);
      const polygon = document.createElementNS(SVG, 'polygon');
      polygon.setAttribute('points', book.quad.map(point => point.join(',')).join(' '));
      const title = document.createElementNS(SVG, 'title');
      title.textContent = book.title;
      link.append(title, polygon);
      link.addEventListener('click', event => { event.preventDefault(); this.openBook(book); });
      link.addEventListener('keydown', event => { if (event.key === ' ') { event.preventDefault(); this.openBook(book); } });
      link.addEventListener('pointerenter', () => this.showHover(book));
      link.addEventListener('pointerleave', () => this.showHover(null));
      link.addEventListener('focus', () => this.showHover(book));
      link.addEventListener('blur', () => this.showHover(null));
      svg.append(link);
    }
    this.$('.photo-view').replaceChildren(svg);
    this.$('.photo-select').value = String(this.photoIndex);
  }

  showHover(book) {
    const label = this.$('.hover-label');
    label.hidden = !book;
    if (book) label.replaceChildren(document.createTextNode(book.title), element('small', '', `SHELF ${book.shelf} · BOOK ${book.position}`));
  }

  openBook(book) {
    if (!book) return;
    if (!this.dialog.open) this.returnFocus = this.shadowRoot.activeElement || document.activeElement;
    this.currentBook = book;
    this.$('.book-title').textContent = book.title;
    this.$('.author').textContent = book.author || 'Author not yet identified';
    this.$('.eyebrow').textContent = book.subject;
    this.$('.description').textContent = book.description;
    this.$('.dialog-location').textContent = `SHELF ${book.shelf} / BOOK ${String(book.position).padStart(2, '0')}`;
    const figure = this.$('.cover-figure');
    figure.replaceChildren();
    const showSpine = () => {
      if (this.currentBook?.id !== book.id) return;
      const placeholder = element('div', 'missing-cover');
      const spine = this.spines?.get(book.id);
      if (spine) {
        const copy = document.createElement('canvas');
        copy.width = spine.width; copy.height = spine.height;
        copy.getContext('2d').drawImage(spine, 0, 0);
        copy.setAttribute('role', 'img');
        copy.setAttribute('aria-label', 'Spine from your photograph');
        placeholder.append(copy);
      }
      placeholder.append(element('span', '', 'A verified cover is not available yet.'));
      figure.replaceChildren(placeholder);
    };
    if (book.cover) {
      const image = element('img');
      image.alt = `Cover of ${book.title}`;
      image.src = assetURL(book.cover);
      image.addEventListener('error', showSpine, { once: true });
      figure.append(image, element('figcaption', 'cover-note', book.coverNote || (book.editionMatch === 'exact' ? 'Cover matched to the photographed edition.' : 'Cover matched by title; your edition may differ.')));
    } else showSpine();
    const meta = this.$('.book-meta');
    meta.replaceChildren();
    const fields = [['Location', `${book.shelf} · ${book.position} from the left`], ['Identification', book.identification === 'uncertain' ? 'Title or author needs confirmation' : 'Matched from the photographed spine']];
    if (book.isbn && book.cover) fields.push(['Cover ISBN', book.isbn]);
    for (const [key, value] of fields) meta.append(element('dt', '', key), element('dd', '', value));
    const sources = this.$('.source-links');
    sources.replaceChildren();
    if (book.sourceURL) {
      const link = externalLink(book.sourceURL, 'Book reference ↗');
      if (link) sources.append(link);
    }
    const index = this.catalog.books.indexOf(book);
    this.$('.previous').disabled = index === 0;
    this.$('.next').disabled = index === this.catalog.books.length - 1;
    if (!this.dialog.open) this.dialog.showModal();
    this.dialog.scrollTop = 0;
    this.dispatchEvent(new CustomEvent('book-open', { detail: { id: book.id, title: book.title, shelf: book.shelf }, bubbles: true, composed: true }));
  }

  stepBook(direction) {
    this.openBook(this.catalog.books[this.catalog.books.indexOf(this.currentBook) + direction]);
  }
}

if (!customElements.get('virtual-bookshelf')) customElements.define('virtual-bookshelf', VirtualBookshelf);
