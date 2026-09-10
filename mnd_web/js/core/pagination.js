/**
 * MND Admin — Firestore cursor pager.
 *
 * Replaces a fixed `.limit(200)` (which silently caps a list and can hide
 * older rows entirely) with real forward/backward paging through the full
 * collection, ordered by whatever the caller's query already orders by.
 *
 * Usage:
 *   const pager = MndPagination.createPager({
 *     query: db.collection('orders').orderBy('createdAt', 'desc'),
 *     pageSize: 50,
 *     getOpts: FS_GET_SERVER, // optional, passed through to .get()
 *   });
 *   const page1 = await pager.first();   // [{id, ...}, ...]
 *   const page2 = await pager.next();    // advances if there is a next page
 *   const backTo1 = await pager.prev();  // goes back if not already first
 *   pager.hasNext(); pager.hasPrev(); pager.pageNumber();
 */
(function (global) {
  function createPager(opts) {
    const baseQuery = opts.query;
    const pageSize = opts.pageSize || 50;
    const getOpts = opts.getOpts;

    // cursors[i] is the doc to startAfter() to land on page i (0-indexed).
    // cursors[0] is always null (first page starts at the top).
    let cursors = [null];
    let pageIndex = 0;
    let hasNextPage = false;
    let lastPageDocs = [];

    async function fetchPage(index) {
      let q = baseQuery.limit(pageSize);
      const cursor = cursors[index];
      if (cursor) q = q.startAfter(cursor);
      const snap = await q.get(getOpts);
      const docs = snap.docs;
      hasNextPage = docs.length === pageSize;
      if (hasNextPage && cursors.length === index + 1) {
        cursors.push(docs[docs.length - 1]);
      }
      pageIndex = index;
      lastPageDocs = docs.map((d) => ({ id: d.id, ...d.data() }));
      return lastPageDocs;
    }

    return {
      first: () => fetchPage(0),
      next: () => (hasNextPage ? fetchPage(pageIndex + 1) : Promise.resolve(lastPageDocs)),
      prev: () => (pageIndex > 0 ? fetchPage(pageIndex - 1) : Promise.resolve(lastPageDocs)),
      hasNext: () => hasNextPage,
      hasPrev: () => pageIndex > 0,
      pageNumber: () => pageIndex + 1,
    };
  }

  global.MndPagination = { createPager };
})(window);
