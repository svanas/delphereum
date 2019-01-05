unit web3;

{$I web3.inc}

interface

type
  TWeb3 = record
    var
      URL: string;
    class function New(const aURL: string): TWeb3; static;
  end;

implementation

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result.URL := aURL;
end;

end.
