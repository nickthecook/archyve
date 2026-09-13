# Solid Queue reschedules a recurring task from the slot that just ran rather
# than from now (Scheduler::RecurringSchedule#schedule_task), and #schedule
# clamps an already-past run_at to a 0.1s delay. A process that loses wall-clock
# time — a laptop resuming from suspend, a paused container — therefore replays
# every slot it slept through, ten a second, until it catches up: an hour
# asleep is sixty heartbeats in six seconds.
#
# Both recurring tasks are heartbeats whose next run subsumes any missed one —
# "which sources are due *now*", "clear finished jobs" — so a replayed slot has
# nothing new to say. For source syncs it is worse than noise: the replayed
# ticks enqueue a scan per due source faster than the scans can mark themselves
# running, so Source.due_for_sync keeps saying yes and the scans pile up behind
# SyncJob's per-source lock.
#
# So: when the next slot has already passed, skip the backlog and take the next
# one in the future. The timer pending at suspend still fires on resume, which
# means a missed schedule costs exactly one catch-up run instead of one per slot.
module SolidQueueSkipMissedRuns
  def schedule_task(task, run_at: task.next_time)
    super(task, run_at: run_at.past? ? task.next_time : run_at)
  end
end

SolidQueue::Scheduler::RecurringSchedule.prepend(SolidQueueSkipMissedRuns)
