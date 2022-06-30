{$IFNDEF VCL}
  {$IFNDEF FMX}
    {$Message Fatal 'VCL or FMX not defined, aborting. This application contains cross-framework references. Please add $(FrameworkType) as a conditional define in this project''s options.'}
  {$ENDIF}
{$ENDIF}
