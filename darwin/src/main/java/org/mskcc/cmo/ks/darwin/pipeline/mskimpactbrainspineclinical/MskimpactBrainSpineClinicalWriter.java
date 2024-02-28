/*
 * Copyright (c) 2016, 2023 Memorial Sloan Kettering Cancer Center.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY, WITHOUT EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS
 * FOR A PARTICULAR PURPOSE. The software and documentation provided hereunder
 * is on an "as is" basis, and Memorial Sloan Kettering Cancer Center has no
 * obligations to provide maintenance, support, updates, enhancements or
 * modifications. In no event shall Memorial Sloan Kettering Cancer Center be
 * liable to any party for direct, indirect, special, incidental or
 * consequential damages, including lost profits, arising out of the use of this
 * software and its documentation, even if Memorial Sloan Kettering Cancer
 * Center has been advised of the possibility of such damage.
 */

/*
 * This file is part of cBioPortal CMO-Pipelines.
 *
 * cBioPortal is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

package org.mskcc.cmo.ks.darwin.pipeline.mskimpactbrainspineclinical;

import com.google.common.base.Strings;
import java.io.*;
import java.util.*;
import org.mskcc.cmo.ks.darwin.pipeline.model.MskimpactBrainSpineClinical;
import org.springframework.batch.item.*;
import org.springframework.batch.item.file.*;
import org.springframework.batch.item.file.transform.PassThroughLineAggregator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.*;

/**
 *
 * @author jake
 */
public class MskimpactBrainSpineClinicalWriter implements ItemStreamWriter<String>{
    @Value("#{jobParameters[outputDirectory]}")
    private String outputDirectory;

    @Value("${darwin.brainspine_clinical_filename}")
    private String datasetFilename;

    private int recordsWritten;
    private Chunk<String> writeList = new Chunk<>();
    private FlatFileItemWriter<String> flatFileItemWriter = new FlatFileItemWriter<>();
    private File stagingFile;

    @Override
    public void open(ExecutionContext executionContext) throws ItemStreamException{
        PassThroughLineAggregator aggr = new PassThroughLineAggregator();
        flatFileItemWriter.setLineAggregator(aggr);
        flatFileItemWriter.setHeaderCallback(new FlatFileHeaderCallback(){
            @Override
            public void writeHeader(Writer writer) throws IOException{
                writer.write(String.join("\t", new MskimpactBrainSpineClinical().getHeaders()));
            }
        });
        stagingFile = new File(outputDirectory, datasetFilename);
        flatFileItemWriter.setResource(new FileSystemResource(stagingFile));
        flatFileItemWriter.open(executionContext);
    }

    @Override
    public void update(ExecutionContext executionContext) throws ItemStreamException{}

    @Override
    public void close() throws ItemStreamException{
        if (recordsWritten == 0) {
            throw new RuntimeException("No records were written to output file: " + stagingFile.getName() + " - exiting...");
        }
        flatFileItemWriter.close();
    }

    @Override
    public void write(Chunk<? extends String> items) throws Exception{
        writeList.clear();
        for(String result : items){
            if (!Strings.isNullOrEmpty(result)) {
                writeList.add(result);
                recordsWritten++;
            }
        }
        flatFileItemWriter.write(writeList);
    }
}
