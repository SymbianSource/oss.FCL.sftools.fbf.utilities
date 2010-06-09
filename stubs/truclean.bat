@REM Copyright (c) 2009 Symbian Foundation Ltd
@REM This component and the accompanying materials are made available
@REM under the terms of the License "Eclipse Public License v1.0"
@REM which accompanies this distribution, and is available
@REM at the URL "http://www.eclipse.org/legal/epl-v10.html".
@REM
@REM Initial Contributors:
@REM Symbian Foundation Ltd - initial contribution.
@REM
@REM Contributors:
@REM
@REM Description:
@REM Invokes the tool by call to the related interpreter

@SETLOCAL
@IF NOT "%PDT_HOME%"=="" (
SET UTILITIES_HOME=%PDT_HOME%\utilities
) ELSE (
SET UTILITIES_HOME=%~dp0\..
)

@perl %UTILITIES_HOME%\uh_parser\truclean.pl %*

@ENDLOCAL
