-- 检查任务实例化，时间串行
SELECT
	task_id,
	task_state,
	b.start_time,
	b.end_time,
	MIN(run_time),
	MAX(run_time),
	a.create_time,
	name,
	description,
	task_cycle,
	cycle_value,
	date_serial
FROM t_task_pool a
INNER JOIN t_task b 
ON a.task_id = b.id
GROUP BY 1, 2
ORDER BY 1;
