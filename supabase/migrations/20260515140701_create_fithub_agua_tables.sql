-- Migration: create_fithub_agua_tables
-- Criando tabelas vinculadas ao ecossistema AHUB para o app de Hidratação

CREATE TABLE IF NOT EXISTS public.fithub_agua_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, -- FK referenciando a tabela de auth/users central do AHUB
    amount_ml INTEGER NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fithub_agua_reminders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    interval_minutes INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS (Row Level Security) - Habilitando políticas
ALTER TABLE public.fithub_agua_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fithub_agua_reminders ENABLE ROW LEVEL SECURITY;

-- Políticas para fithub_agua_records
CREATE POLICY "Users can insert their own records"
ON public.fithub_agua_records FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own records"
ON public.fithub_agua_records FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Políticas para fithub_agua_reminders
CREATE POLICY "Users can insert their own reminders"
ON public.fithub_agua_reminders FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own reminders"
ON public.fithub_agua_reminders FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own reminders"
ON public.fithub_agua_reminders FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);
