-- Add leader_id to responder for grouping first aider/responder teams.
-- When assigning a leader to a report, assign leader + all responders where leader_id = leader.id.
ALTER TABLE public.responder
ADD COLUMN IF NOT EXISTS leader_id uuid REFERENCES public.responder(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_responder_leader_id ON public.responder(leader_id);
COMMENT ON COLUMN public.responder.leader_id IS 'Optional: responder id of the team leader (first_aider_leader / responder_leader).';

-- Optional team/group name (e.g. "First Aider Team A") so multiple teams are easy to identify and assign by group.
ALTER TABLE public.responder
ADD COLUMN IF NOT EXISTS team_name text;

CREATE INDEX IF NOT EXISTS idx_responder_team_name ON public.responder(team_name);
COMMENT ON COLUMN public.responder.team_name IS 'Optional: group/team name (e.g. First Aider Team A). Leaders set this; assign UI groups by team.';
