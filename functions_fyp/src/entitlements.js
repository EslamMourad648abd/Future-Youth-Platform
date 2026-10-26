export function hasActiveCourseSubscription(subscriptionDocs, studentId, courseId, nowMs = Date.now()) {
  return subscriptionDocs.some((doc) => {
    const data = typeof doc?.data === "function" ? doc.data() : doc;
    const expiresAt = data?.expiresAt?.toMillis?.();
    return data?.studentId === studentId &&
      data?.courseId === courseId &&
      data?.status === "active" &&
      typeof expiresAt === "number" &&
      expiresAt > nowMs;
  });
}
