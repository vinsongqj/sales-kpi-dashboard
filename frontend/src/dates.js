// The business runs on Malaysia time, whatever timezone the viewer's browser
// is in. "en-CA" formats dates as YYYY-MM-DD, the same shape the API uses.
const MYT_DATE = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Kuala_Lumpur",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/** Today's date in Malaysia as "YYYY-MM-DD". */
export const todayMYT = () => MYT_DATE.format(new Date());

/** The current month in Malaysia as "YYYY-MM". */
export const currentMonthMYT = () => todayMYT().slice(0, 7);
