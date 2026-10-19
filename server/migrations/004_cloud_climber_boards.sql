-- Cloud Climber board definitions. Scores are the climbed height in metres.
-- `daily-v1` is shared by dated ids (`daily-v1_YYYYMMDD`, one ranking per UTC day);
-- `endless-v1` is the all-time random-seed ranking. Immutable once scores exist:
-- changed scoring rules need a new board id.
INSERT IGNORE INTO game_lb_boards
(namespace,id,rules_version,direction,min_score,max_score,min_duration_ms,max_duration_ms,`open`)
VALUES
('production','daily-v1','v1','desc',1,200000,3000,1800000,TRUE),
('production','endless-v1','v1','desc',1,200000,3000,1800000,TRUE);
